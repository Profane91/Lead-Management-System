/**
 * Cloudflare Workers Lead Gateway
 * Handles form submissions with spam protection, validation, and forwarding to n8n
 */

import type { ExecutionContext } from '@cloudflare/workers-types';

export interface Env {
  N8N_WEBHOOK_URL: string;
  WORKER_SHARED_SECRET: string;
  ALLOWED_ORIGINS: string;
}

interface LeadData {
  client_id: string;
  name: string;
  phone: string;
  email?: string;
  message: string;
  service?: string;
  source?: string;
  utm?: string;
  website?: string; // honeypot
}

interface ForwardPayload extends Omit<LeadData, 'website'> {
  ip: string;
  user_agent: string;
  timestamp: string;
}

/**
 * CORS headers helper
 */
function getCorsHeaders(origin: string | null, allowedOrigins: string[]): HeadersInit {
  const headers: HeadersInit = {
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type',
    'Access-Control-Max-Age': '86400',
  };

  if (origin && allowedOrigins.includes(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers['Access-Control-Allow-Credentials'] = 'true';
  }

  return headers;
}

/**
 * Parse form data from various content types
 */
async function parseFormData(request: Request): Promise<Record<string, string>> {
  const contentType = request.headers.get('content-type') || '';
  const data: Record<string, string> = {};

  if (contentType.includes('application/json')) {
    const json = await request.json();
    Object.keys(json).forEach(key => {
      data[key] = String(json[key] || '');
    });
  } else if (contentType.includes('application/x-www-form-urlencoded') || contentType.includes('multipart/form-data')) {
    const formData = await request.formData();
    for (const [key, value] of formData.entries()) {
      data[key] = String(value);
    }
  } else {
    throw new Error('Unsupported content type');
  }

  return data;
}

/**
 * Validate required fields and constraints
 */
function validateLeadData(data: Record<string, string>): { valid: boolean; error?: string } {
  // Required fields
  if (!data.client_id || !data.name || !data.phone || !data.message) {
    return { valid: false, error: 'Missing required fields: client_id, name, phone, message' };
  }

  // Name validation
  if (data.name.trim().length < 2) {
    return { valid: false, error: 'Name must be at least 2 characters' };
  }

  // Phone validation
  if (data.phone.trim().length < 7) {
    return { valid: false, error: 'Phone must be at least 7 characters' };
  }

  // Message validation
  if (data.message.trim().length > 2000) {
    return { valid: false, error: 'Message must not exceed 2000 characters' };
  }

  // Email validation (if provided)
  if (data.email && data.email.trim().length > 0) {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(data.email.trim())) {
      return { valid: false, error: 'Invalid email format' };
    }
  }

  return { valid: true };
}

/**
 * Check if origin is allowed
 */
function isOriginAllowed(origin: string | null, allowedOriginsStr: string): boolean {
  if (!origin) return true; // No origin header means non-browser request (ok for testing)
  
  const allowedOrigins = allowedOriginsStr
    .split(',')
    .map(o => o.trim())
    .filter(o => o.length > 0);

  return allowedOrigins.includes(origin);
}

/**
 * Forward lead to n8n webhook
 */
async function forwardToN8n(
  payload: ForwardPayload,
  webhookUrl: string,
  secret: string
): Promise<{ success: boolean; error?: string }> {
  try {
    const response = await fetch(webhookUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Lead-Secret': secret,
      },
      body: JSON.stringify(payload),
    });

    if (!response.ok) {
      return {
        success: false,
        error: `n8n webhook returned ${response.status}: ${response.statusText}`,
      };
    }

    return { success: true };
  } catch (error) {
    return {
      success: false,
      error: `Failed to forward to n8n: ${error instanceof Error ? error.message : 'Unknown error'}`,
    };
  }
}

/**
 * Handle POST /submit
 */
async function handleSubmit(request: Request, env: Env): Promise<Response> {
  const origin = request.headers.get('origin');
  const allowedOrigins = env.ALLOWED_ORIGINS.split(',').map(o => o.trim()).filter(o => o.length > 0);

  // Origin check
  if (!isOriginAllowed(origin, env.ALLOWED_ORIGINS)) {
    return new Response('Forbidden', {
      status: 403,
      headers: getCorsHeaders(origin, allowedOrigins),
    });
  }

  try {
    // Parse form data
    const data = await parseFormData(request);

    // Honeypot check - if website field is filled, it's a bot
    if (data.website && data.website.trim().length > 0) {
      console.log('Honeypot triggered, rejecting spam submission');
      // Return success to fool the bot
      return new Response('OK', {
        status: 200,
        headers: getCorsHeaders(origin, allowedOrigins),
      });
    }

    // Validate data
    const validation = validateLeadData(data);
    if (!validation.valid) {
      return new Response(JSON.stringify({ error: validation.error }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json',
          ...getCorsHeaders(origin, allowedOrigins),
        },
      });
    }

    // Build payload with metadata
    const payload: ForwardPayload = {
      client_id: data.client_id.trim(),
      name: data.name.trim(),
      phone: data.phone.trim(),
      message: data.message.trim(),
      email: data.email?.trim() || undefined,
      service: data.service?.trim() || undefined,
      source: data.source?.trim() || undefined,
      utm: data.utm?.trim() || undefined,
      ip: request.headers.get('CF-Connecting-IP') || 'unknown',
      user_agent: request.headers.get('User-Agent') || 'unknown',
      timestamp: new Date().toISOString(),
    };

    // Forward to n8n
    const forwardResult = await forwardToN8n(payload, env.N8N_WEBHOOK_URL, env.WORKER_SHARED_SECRET);

    if (!forwardResult.success) {
      console.error('Failed to forward lead:', forwardResult.error);
      return new Response('Service temporarily unavailable', {
        status: 502,
        headers: getCorsHeaders(origin, allowedOrigins),
      });
    }

    // Success - redirect to thank you page
    const referer = request.headers.get('Referer') || origin || '';
    let thanksUrl = '/thanks';
    
    // Try to construct thanks URL from referer or origin
    if (referer) {
      try {
        const refererUrl = new URL(referer);
        thanksUrl = `${refererUrl.origin}/thanks`;
      } catch {
        // If referer is invalid, try origin
        if (origin) {
          thanksUrl = `${origin}/thanks`;
        }
      }
    }

    return new Response(null, {
      status: 302,
      headers: {
        'Location': thanksUrl,
        ...getCorsHeaders(origin, allowedOrigins),
      },
    });
  } catch (error) {
    console.error('Error processing submission:', error);
    return new Response(JSON.stringify({ error: 'Invalid request' }), {
      status: 400,
      headers: {
        'Content-Type': 'application/json',
        ...getCorsHeaders(origin, allowedOrigins),
      },
    });
  }
}

/**
 * Handle OPTIONS for CORS preflight
 */
function handleOptions(request: Request, env: Env): Response {
  const origin = request.headers.get('origin');
  const allowedOrigins = env.ALLOWED_ORIGINS.split(',').map(o => o.trim()).filter(o => o.length > 0);

  return new Response(null, {
    status: 204,
    headers: getCorsHeaders(origin, allowedOrigins),
  });
}

/**
 * Main worker entry point
 */
export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    const url = new URL(request.url);

    // Handle OPTIONS for CORS
    if (request.method === 'OPTIONS') {
      return handleOptions(request, env);
    }

    // Handle POST /submit
    if (request.method === 'POST' && url.pathname === '/submit') {
      return handleSubmit(request, env);
    }

    // Handle health check
    if (request.method === 'GET' && url.pathname === '/health') {
      return new Response(JSON.stringify({ status: 'ok', timestamp: new Date().toISOString() }), {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // 404 for everything else
    return new Response('Not Found', { status: 404 });
  },
};
