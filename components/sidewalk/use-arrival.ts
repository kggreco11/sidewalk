'use client';
import {useEffect,useRef,useState} from 'react';
import {arrivalCheck} from '@/lib/arrival';
const key='sidewalk.unlocked.v1';
export function useArrival(){
 const [ids,setIds]=useState<string[]>([]),[pending,setPending]=useState<string|null>(null),[error,setError]=useState<{id:string;message:string}|null>(null);
 const current=useRef<string[]>([]),busy=useRef(false),generation=useRef(0),ready=useRef(false);
 useEffect(()=>{try{const stored=JSON.parse(localStorage.getItem(key)||'[]');if(!Array.isArray(stored)||!stored.every(v=>typeof v==='string'))throw Error();current.current=stored;setIds(stored);ready.current=true}catch{ready.current=false}return()=>{generation.current++}},[]);
 async function verify(place:{id:string;lat:number;lng:number}){
  if(busy.current)return false;
  if(!ready.current){setError({id:place.id,message:'Your unlocked stories could not be read. Reload before checking in.'});return false}
  busy.current=true;setPending(place.id);setError(null);const request=++generation.current;
  try{
   if(!navigator.geolocation)throw Error('Location is unavailable on this device.');
   const fix=await new Promise<GeolocationPosition>((resolve,reject)=>{
    const timer=setTimeout(()=>reject(Error('Location took too long. Try again outdoors.')),20000);
    navigator.geolocation.getCurrentPosition(p=>{clearTimeout(timer);resolve(p)},e=>{clearTimeout(timer);reject(Error(e.code===1?'Allow location for Sidewalk in your browser settings to unlock this story.':'Couldn’t confirm your location. Try again outdoors.'))},{enableHighAccuracy:true,maximumAge:0,timeout:15000});
   });
   if(request!==generation.current)return false;
   if(document.hidden)throw Error('Return to the walk and check in again.');
   const result=arrivalCheck({lat:fix.coords.latitude,lng:fix.coords.longitude,accuracy:fix.coords.accuracy,timestamp:fix.timestamp},place);
   if(!result.ok)throw Error(result.message);
   const next=[...new Set([...current.current,place.id])];
   try{localStorage.setItem(key,JSON.stringify(next))}catch{throw Error('Couldn’t save this unlock. Allow site storage and try again.')}
   current.current=next;setIds(next);return true;
  }catch(e){if(request===generation.current)setError({id:place.id,message:e instanceof Error?e.message:'Couldn’t confirm your arrival.'});return false}
  finally{busy.current=false;if(request===generation.current)setPending(null)}
 }
 return {ids,pending,error,verify};
}
