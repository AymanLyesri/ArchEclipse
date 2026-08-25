// Single source of truth for Supabase connection settings.
// Import from here everywhere; do NOT hardcode these in other files.

export const SUPABASE_URL = "https://skekmjmsgcbfhbwgpzkp.supabase.co";
export const SUPABASE_PUB_KEY = "sb_publishable_PLXFIwBsb79Gfu3YkW5B-w_rHozkZ1y";

export const supabaseHeaders = (accessToken?: string): Record<string, string> => ({
  apikey: SUPABASE_PUB_KEY,
  ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
});
