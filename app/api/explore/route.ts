import {explorePlaces} from '@/lib/place-catalog';
export async function GET(){return Response.json({places:explorePlaces.map(({facts,...place})=>place)},{headers:{'Cache-Control':'public, max-age=300'}})}
