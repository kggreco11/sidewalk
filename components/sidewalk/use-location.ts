'use client';
import {useEffect,useState} from 'react';
import type {Fix} from '@/lib/live-walk';
export function useLocation(active:boolean){
 const [fix,setFix]=useState<Fix|null>(null),[status,setStatus]=useState('Location off'),[retry,setRetry]=useState(0),[now,setNow]=useState(Date.now());
 useEffect(()=>{
  if(!active){setFix(null);setStatus('Location off');return;}
  let watch:number|undefined,disposed=false,generation=0;
  const stop=()=>{generation++;if(watch!==undefined)navigator.geolocation?.clearWatch(watch);watch=undefined;setFix(null)};
  const start=()=>{
   stop();if(document.hidden){setStatus('Location paused while away');return;}
   if(!navigator.geolocation){setStatus('Location unavailable — check in manually');return;}
   setStatus('Finding your location…');const current=generation;
   watch=navigator.geolocation.watchPosition(p=>{if(disposed||current!==generation)return;setFix({lat:p.coords.latitude,lng:p.coords.longitude,accuracy:p.coords.accuracy,timestamp:p.timestamp});setNow(Date.now());setStatus('Live location')},e=>{if(disposed||current!==generation)return;setFix(null);setStatus(e.code===1?'Location access denied — check in manually':e.code===3?'GPS timed out — retry or check in manually':'GPS unavailable — check in manually')},{enableHighAccuracy:true,maximumAge:5000,timeout:15000});
  };
  const visibility=()=>start();start();document.addEventListener('visibilitychange',visibility);const timer=setInterval(()=>setNow(Date.now()),5000);
  return()=>{disposed=true;stop();clearInterval(timer);document.removeEventListener('visibilitychange',visibility)};
 },[active,retry]);
 return {fix,status,now,retry:()=>setRetry(v=>v+1)};
}
