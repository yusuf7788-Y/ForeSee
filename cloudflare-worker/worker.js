// Cloudflare Worker - OpenRouter Streaming Proxy
// Bu worker API key'i güvende tutar ve streaming destekler

export default {
    async fetch(request, env) {
        // CORS headers
        const corsHeaders = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
        };

        // OPTIONS request (preflight)
        if (request.method === 'OPTIONS') {
            return new Response(null, { headers: corsHeaders });
        }

        // Sadece POST kabul et
        if (request.method !== 'POST') {
            return new Response('Method not allowed', { status: 405 });
        }

        try {
            // Request body'yi al
            const body = await request.json();

            // OpenRouter API'ye istek gönder
            const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${env.OPENROUTER_API_KEY}`, // Environment variable'dan
                    'Content-Type': 'application/json',
                    'HTTP-Referer': 'https://foresee.app',
                    'X-Title': 'ForeSee AI',
                },
                body: JSON.stringify(body),
            });

            // Hata kontrolü
            if (!response.ok) {
                const errorText = await response.text();
                return new Response(errorText, {
                    status: response.status,
                    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
                });
            }

            // Streaming response'u direkt döndür
            return new Response(response.body, {
                headers: {
                    ...corsHeaders,
                    'Content-Type': 'text/event-stream',
                    'Cache-Control': 'no-cache',
                    'Connection': 'keep-alive',
                },
            });
        } catch (error) {
            return new Response(JSON.stringify({ error: error.message }), {
                status: 500,
                headers: { ...corsHeaders, 'Content-Type': 'application/json' },
            });
        }
    },
};
