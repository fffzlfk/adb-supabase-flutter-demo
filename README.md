# AI Image Editor App

A Flutter application that edits images based on text prompts using Supabase Edge Functions and AI models.


### 1. Supabase Configuration

```bash
cp .env.example .env
```

Edit the `.env` file with your Supabase SUPABASE_URL, SUPABASE_SERVICE_KEY.

### 2. Database Setup

Create a table for storing generated images (optional, for history feature):

```sql
CREATE TABLE public.edited_images (
    id TEXT PRIMARY KEY,
    prompt TEXT NOT NULL,
    original_image_url TEXT NOT NULL,
    edited_image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE edited_images ENABLE ROW LEVEL SECURITY;

-- Create a policy that allows all operations (adjust based on your needs)
CREATE POLICY "Allow all operations on edited_images" ON edited_images FOR ALL USING (true);
```

### 3. Create Storage Bucket

Create a storage bucket named `images`.


### 4. Edge Function Setup

Create a Supabase Edge Function named `wan`:


```typescript
const DASHSCOPE_API_KEY = Deno.env.get('BAILIAN_API_KEY');
const BASE_URL = 'https://vpc-cn-beijing.dashscope.aliyuncs.com/api/v1';
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
```

### 5. Secret Key Setup

Set up your API keys in Supabase secrets:

```bash
BAILIAN_API_KEY=sk-xxxxxxxxxxxxxxxxxxxxxxxxxxxx
```

## Running the App

1. Install dependencies:
```bash
flutter pub get
```

2. Run the app:
```bash
flutter run
```