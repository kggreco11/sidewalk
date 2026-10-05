import catalog from '@/lib/data/catalog.json';
export async function GET(){return Response.json({ai:!!process.env.OPENAI_API_KEY,catalog},{headers:{'Cache-Control':'no-store'}})}
