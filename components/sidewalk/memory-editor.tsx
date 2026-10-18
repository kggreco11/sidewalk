'use client';
import {useId,useRef,useState} from 'react';
import {Camera,ImagePlus,Check,X} from 'lucide-react';
import type {CollectedPlace} from '@/lib/collection';
async function preparePhoto(file:File):Promise<string>{
  if(!file.type.startsWith('image/'))throw Error('Choose an image file.');
  if(file.size>25*1024*1024)throw Error('Choose a photo under 25 MB.');
  const url=URL.createObjectURL(file);
  try{
    const image=new Image();image.src=url;await image.decode();
    const scale=Math.min(1,960/Math.max(image.naturalWidth,image.naturalHeight));
    const canvas=document.createElement('canvas');canvas.width=Math.max(1,Math.round(image.naturalWidth*scale));canvas.height=Math.max(1,Math.round(image.naturalHeight*scale));
    const ctx=canvas.getContext('2d');if(!ctx)throw Error('Photo processing is unavailable.');
    ctx.fillStyle='#fff';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.drawImage(image,0,0,canvas.width,canvas.height);
    return canvas.toDataURL('image/jpeg',.72);
  }catch{throw Error('This photo could not be opened. Try a JPEG, PNG, or WebP image.')}finally{URL.revokeObjectURL(url)}
}
export default function MemoryEditor({place,onSave}:{place:CollectedPlace;onSave:(note:string,photo?:string)=>boolean}){
 const [note,setNote]=useState(place.note),[photo,setPhoto]=useState(place.photo),[busy,setBusy]=useState(false),[error,setError]=useState(''),[saved,setSaved]=useState(false);
 const camera=useRef<HTMLInputElement>(null),upload=useRef<HTMLInputElement>(null),id=useId();
 async function choose(file?:File){if(!file)return;setBusy(true);setSaved(false);setError('');try{setPhoto(await preparePhoto(file))}catch(e){setError((e as Error).message)}finally{setBusy(false)}}
 return <div className="memory-editor"><div className="memory-photo-actions"><button type="button" onClick={()=>camera.current?.click()} disabled={busy}><Camera size={17}/>Snap this spot</button><button type="button" onClick={()=>upload.current?.click()} disabled={busy}><ImagePlus size={17}/>From your camera roll</button></div><input ref={camera} type="file" accept="image/*" capture="environment" hidden aria-label="Take a photo" onChange={e=>{void choose(e.target.files?.[0]);e.target.value=''}}/><input ref={upload} type="file" accept="image/*" hidden aria-label="Choose photo" onChange={e=>{void choose(e.target.files?.[0]);e.target.value=''}}/>{busy&&<p role="status">Preparing photo…</p>}{photo&&<div className="memory-photo"><img src={photo} alt={`Your photo of ${place.name}`}/><button type="button" onClick={()=>{setPhoto(undefined);setSaved(false)}} aria-label="Remove photo"><X size={16}/></button></div>}<label htmlFor={id}>Worth a footnote? <small>optional</small></label><textarea id={id} value={note} maxLength={1000} onChange={e=>{setNote(e.target.value);setSaved(false)}} placeholder="The detail the guidebook missed…"/>{error&&<p role="alert" className="collection-error">{error}</p>}<button type="button" className="primary-action" disabled={busy} onClick={()=>setSaved(onSave(note,photo))}>{saved?'Moment saved':'Keep this moment'}<Check size={17}/></button><small className="memory-local">Photos and notes stay in this browser.</small></div>;
}
