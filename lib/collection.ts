import type {Place} from './types';
export type CollectedPlace=Pick<Place,'id'|'name'|'category'|'lat'|'lng'> & {visits:string[];note:string;photo?:string};
export type Collection={places:CollectedPlace[];walks:string[]};
export const collectionKey='sidewalk.collection.v1';
export const emptyCollection=():Collection=>({places:[],walks:[]});
export function readCollection(raw:string|null):Collection {
  if(!raw)return emptyCollection();
  const value=JSON.parse(raw);
  if(!value||!Array.isArray(value.places)||!Array.isArray(value.walks)||!value.walks.every((s:unknown)=>typeof s==='string'))throw Error('Invalid collection');
  for(const p of value.places)if(!p||!['id','name','category','note'].every(k=>typeof p[k]==='string')||(p.photo!==undefined&&(typeof p.photo!=='string'||!p.photo.startsWith('data:image/jpeg;base64,')))||!Number.isFinite(p.lat)||!Number.isFinite(p.lng)||!Array.isArray(p.visits)||!p.visits.length||!p.visits.every((s:unknown)=>typeof s==='string'&&Number.isFinite(Date.parse(s))))throw Error('Invalid stamp');
  return value;
}
export function collectPlace(collection:Collection,place:Place,date:string):Collection {
  const existing=collection.places.find(p=>p.id===place.id);
  return {...collection,places:existing?collection.places.map(p=>p.id===place.id?{...p,visits:[...p.visits,date]}:p):[{id:place.id,name:place.name,category:place.category,lat:place.lat,lng:place.lng,visits:[date],note:''},...collection.places]};
}
export function milestones(c:Collection){return [
  {name:'First discovery',detail:'Visit your first place',count:c.places.length,goal:1},
  {name:'Film scout',detail:'Discover 3 film locations',count:c.places.filter(p=>/film/i.test(p.category)).length,goal:3},
  {name:'City explorer',detail:'Discover 10 different places',count:c.places.length,goal:10},
  {name:'A walk well spent',detail:'Visit every stop and finish a walk',count:c.walks.length,goal:1},
];}
