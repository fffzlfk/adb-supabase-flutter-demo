CREATE TABLE public.edited_images (
    id TEXT PRIMARY KEY,
    prompt TEXT NOT NULL,
    original_image_url TEXT NOT NULL,
    edited_image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);