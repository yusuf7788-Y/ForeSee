const functions = require('firebase-functions');
const fetch = require('node-fetch');

// OpenRouter Proxy Function
exports.proxyOpenRouter = functions.https.onCall(async (data, context) => {
    try {
        // API anahtarını Firebase environment variable'dan al
        const apiKey = functions.config().openrouter.key;

        if (!apiKey) {
            throw new functions.https.HttpsError(
                'failed-precondition',
                'OpenRouter API key not configured'
            );
        }

        const { messages, model, maxTokens, temperature, tools, toolChoice } = data;

        // OpenRouter API'ye istek gönder
        const response = await fetch('https://openrouter.ai/api/v1/chat/completions', {
            method: 'POST',
            headers: {
                'Authorization': `Bearer ${apiKey}`,
                'Content-Type': 'application/json',
                'HTTP-Referer': 'https://foresee.app',
                'X-Title': 'ForeSee AI',
            },
            body: JSON.stringify({
                model: model,
                messages: messages,
                max_tokens: maxTokens || 3600,
                temperature: temperature || 0.7,
                stream: false, // Cloud Functions doesn't support streaming well
                ...(tools && { tools, tool_choice: toolChoice || 'auto' }),
            }),
        });

        if (!response.ok) {
            const errorBody = await response.text();
            throw new functions.https.HttpsError(
                'internal',
                `OpenRouter API error: ${response.status} - ${errorBody}`
            );
        }

        const result = await response.json();
        return result;
    } catch (error) {
        console.error('Proxy error:', error);
        throw new functions.https.HttpsError('internal', error.message);
    }
});
