import original from './data/places.json';
import additions from './data/explore-places.json';
import type {ExplorePlace} from './explore';
// Prefer the new, sourced record when the same named place occurs in both catalogs.
const normalize=(name:string)=>name.toLowerCase().replace(/[^a-z0-9]/g,'');
const oldIds=new Map((original as ExplorePlace[]).map(p=>[normalize(p.name),p.id]));
const newer=(additions as ExplorePlace[]).map(p=>({...p,id:oldIds.get(normalize(p.name))||p.id}));
const names=new Set(newer.map(p=>normalize(p.name)));
export const allPlaces:ExplorePlace[]=[...newer,...(original as ExplorePlace[]).filter(p=>!names.has(normalize(p.name)))];
export const explorePlaces:ExplorePlace[]=[...newer,...(original as ExplorePlace[]).filter(p=>!names.has(normalize(p.name))&&p.story.length>70&&p.quality>=3)];
