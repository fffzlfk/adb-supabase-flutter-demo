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