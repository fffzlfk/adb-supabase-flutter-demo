const DASHSCOPE_API_KEY = Deno.env.get('BAILIAN_API_KEY');
const BASE_URL = 'https://dashscope.aliyuncs.com/api/v1';
async function callImageEditAPI(image_url, prompt) {
  const messages = [
    {
      role: "user",
      content: [
        {
          image: image_url
        },
        {
          text: prompt
        }
      ]
    }
  ];
  const payload = {
    model: "qwen-image-edit",
    input: {
      messages
    },
    parameters: {
      negative_prompt: "",
      watermark: false
    }
  };
  try {
    const response = await fetch(`${BASE_URL}/services/aigc/multimodal-generation/generation`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${DASHSCOPE_API_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    });
    if (!response.ok) {
      console.error(`Request failed: ${response.status} ${response.statusText}`);
      return null;
    }
    const data = await response.json();
    return data.output?.choices?.[0]?.message?.content ?? null;
  } catch (error) {
    console.error("Request error:", error.message);
    return null;
  }
}
Deno.serve(async (req)=>{
  try {
    const { image_url, prompt } = await req.json();
    if (!image_url || !prompt) {
      return new Response(JSON.stringify({
        error: "Missing image_url or prompt"
      }), {
        status: 400,
        headers: {
          'Content-Type': 'application/json'
        }
      });
    }
    const result = await callImageEditAPI(image_url, prompt);
    return new Response(JSON.stringify({
      message: result
    }), {
      headers: {
        'Content-Type': 'application/json',
        'Connection': 'keep-alive'
      }
    });
  } catch (error) {
    console.error("Server error:", error);
    return new Response(JSON.stringify({
      error: "Internal server error"
    }), {
      status: 500,
      headers: {
        'Content-Type': 'application/json'
      }
    });
  }
});

