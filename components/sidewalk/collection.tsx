'use client';
import {BookOpen,Building2,Clapperboard,TowerControl,Landmark,TreePine,Check,ArrowUpRight,Award} from 'lucide-react';
import {Dialog,DialogContent,DialogTitle,DialogDescription} from '@/components/ui/dialog';
import {milestones,type Collection,type CollectedPlace} from '@/lib/collection';
import {useState} from 'react';
import MemoryEditor from './memory-editor';
import type {ExplorePlace} from '@/lib/explore';
export function Stamp({place}:{place:Pick<CollectedPlace,'name'|'category'>}){
 const Icon=/city lights|book/i.test(place.name)?BookOpen:/ferry|tower/i.test(place.name)?TowerControl:/film/i.test(place.category)?Clapperboard:/park|garden/i.test(place.name)?TreePine:/historic/i.test(place.category)?Landmark:Building2;
 return <span className="collectible-stamp" aria-hidden="true"><span>SF · ON FOOT</span><Icon size={40} strokeWidth={1.2}/><small>SIDEWALK</small></span>;
}
const date=(s:string)=>new Date(s).toLocaleDateString(undefined,{month:'short',day:'numeric',year:'numeric'});
export default function CollectionView({open,onOpenChange,collection,onMemory,error,unlockedPlaces,unlockedIds}:{open:boolean;onOpenChange:(v:boolean)=>void;collection:Collection;onMemory:(id:string,note:string,photo?:string)=>boolean;error:string;unlockedPlaces:ExplorePlace[];unlockedIds:string[]}){
 const [active,setActive]=useState<string|null>(null);
 const place=collection.places.find(p=>p.id===active);
 return <Dialog open={open} onOpenChange={v=>{onOpenChange(v);if(!v)setActive(null)}}><DialogContent className="collection-dialog"><DialogTitle>My field guide</DialogTitle><DialogDescription>{collection.places.length} {collection.places.length===1?'place':'places'} · {collection.walks.length} completed {collection.walks.length===1?'walk':'walks'} · Saved in this browser</DialogDescription>
 {error&&<p role="alert" className="collection-error">{error}</p>}
 <div className="collection-scroll">{place?<section className="stamp-detail"><button className="text-action" onClick={()=>setActive(null)}>← All stamps</button><Stamp place={place}/><span className="eyebrow">{place.category}</span><h2>{place.name}</h2><p>{place.visits.length} {place.visits.length===1?'visit':'visits'} · First discovered {date(place.visits[0])}</p>{unlockedIds.includes(place.id)&&<p className="story">{place.story||unlockedPlaces.find(p=>p.id===place.id)?.story}</p>}<MemoryEditor key={place.id} place={place} onSave={(note,photo)=>onMemory(place.id,note,photo)}/><h3>Visit log</h3><ul>{[...place.visits].reverse().map((v,i)=><li key={`${v}-${i}`}>{date(v)}</li>)}</ul></section>:<>
 {unlockedPlaces.filter(p=>!collection.places.some(c=>c.id===p.id)).map(p=><details className="unlocked-entry" key={p.id}><summary>{p.name}</summary><p className="story">{p.story}</p></details>)}
 <div className="collection-milestones" aria-label="Milestones">{milestones(collection).map(m=><div key={m.name} className={`collection-milestone ${m.count>=m.goal?'earned':''}`}><Award size={20}/><div><strong>{m.name}</strong><small>{m.detail}</small></div><span>{m.count>=m.goal?<><Check size={17}/><span className="sr-only">Earned</span></>:`${Math.min(m.count,m.goal)}/${m.goal}`}</span></div>)}</div>
 {!collection.places.length?<div className="collection-empty"><BookOpen size={38} strokeWidth={1}/><h2>Your first page is waiting.</h2><p>Tap “I’m here” at a stop to collect its stamp.</p><button className="text-action" onClick={()=>onOpenChange(false)}>Explore the city<ArrowUpRight size={17}/></button></div>:<div className="stamp-grid">{collection.places.map(p=><button className="stamp-card" key={p.id} onClick={()=>{setActive(p.id)}}><Stamp place={p}/>{p.photo&&<img className="stamp-photo-preview" src={p.photo} alt={`Your photo of ${p.name}`}/>}<strong>{p.name}</strong><small>{date(p.visits[0])} · {p.visits.length} {p.visits.length===1?'visit':'visits'}</small></button>)}</div>}
 </>}</div></DialogContent></Dialog>;
}
