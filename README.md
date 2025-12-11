# AI Image Editor App

A Flutter application that edits images based on text prompts using Supabase Edge Functions and AI models.


### 1. Supabase Configuration

```bash
cp .env.example .env
```

Edit the `.env` file with your Supabase SUPABASE_URL and SUPABASE_ANON_KEY:

```
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 2. Database Setup

Create a table for storing generated images (for history feature). Run the SQL commands from `schema/table.sql` in your Supabase SQL Editor:

```sql
CREATE TABLE public.edited_images (
    id TEXT PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    prompt TEXT NOT NULL,
    original_image_url TEXT NOT NULL,
    edited_image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE edited_images ENABLE ROW LEVEL SECURITY;

-- Create policy that allows users to see only their own images
CREATE POLICY "Users can view their own edited images"
ON edited_images
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);

-- Create policy that allows users to insert their own images
CREATE POLICY "Users can insert their own edited images"
ON edited_images
FOR INSERT
TO authenticated
WITH CHECK (auth.uid() = user_id);

-- Create policy that allows users to delete their own images
CREATE POLICY "Users can delete their own edited images"
ON edited_images
FOR DELETE
TO authenticated
USING (auth.uid() = user_id);
```

**Note:** The table includes a `user_id` field to ensure users can only access their own image history.

### 3. Create Storage Bucket and Configure RLS Policies

1. Create a storage bucket named `images` via Supabase Dashboard > Storage

2. Configure Row Level Security (RLS) policies for the storage bucket. Run the SQL commands from `schema/storage_policies.sql` in your Supabase SQL Editor:

```sql
-- Allow authenticated users to upload files to their own folder
CREATE POLICY "Allow authenticated users to upload images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow authenticated users to read their own files
CREATE POLICY "Allow authenticated users to read their own images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- Allow public read access (for public URLs)
CREATE POLICY "Allow public read access to images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'images');
```

**Note:** The app organizes uploaded files by user ID (`userId/filename`), so each user can only access their own files.


### 4. Edge Function Setup

Create a Supabase Edge Function named `image-edit`:


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