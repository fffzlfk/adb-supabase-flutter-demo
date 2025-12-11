-- Storage bucket RLS policies for authenticated users
-- Run these SQL commands in your Supabase SQL Editor

-- 1. Create storage bucket (if not exists)
-- Note: You can also create this via the Supabase Dashboard > Storage

-- 2. Enable RLS on the storage.objects table (usually enabled by default)
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 3. Create policy to allow authenticated users to upload files
CREATE POLICY "Allow authenticated users to upload images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 4. Create policy to allow authenticated users to read their own files
CREATE POLICY "Allow authenticated users to read their own images"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 5. Create policy to allow authenticated users to delete their own files
CREATE POLICY "Allow authenticated users to delete their own images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'images' AND
  auth.uid()::text = (storage.foldername(name))[1]
);

-- 6. Create policy to allow public read access (optional, for public URLs)
CREATE POLICY "Allow public read access to images"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'images');

