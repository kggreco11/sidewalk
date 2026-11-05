'use client';
import {useEffect,useRef,useState,type ReactNode} from 'react';
const artworks=['hillside','coast','neighborhood'];
export default function ArrivalScreen({children}:{children:ReactNode}){
 const [visible,setVisible]=useState(true),[leaving,setLeaving]=useState(false),[index,setIndex]=useState<number|null>(null);
 const initialized=useRef(false);
 const skip=useRef<HTMLButtonElement>(null),dismissed=useRef(false),timer=useRef<ReturnType<typeof setTimeout>|undefined>(undefined);
 function dismiss(){if(dismissed.current)return;dismissed.current=true;setLeaving(true);const reduced=window.matchMedia('(prefers-reduced-motion: reduce)').matches;timer.current=setTimeout(()=>{setVisible(false);requestAnimationFrame(()=>document.getElementById('sidewalk-home')?.focus())},reduced?0:240)}
 useEffect(()=>{if(!initialized.current){initialized.current=true;let next=0;try{const raw=Number(localStorage.getItem('sidewalk.arrival.next')||0);next=Number.isInteger(raw)&&raw>=0?raw%artworks.length:0;localStorage.setItem('sidewalk.arrival.next',String((next+1)%artworks.length))}catch{}setIndex(next);}skip.current?.focus();const automatic=setTimeout(dismiss,2600);return()=>{clearTimeout(automatic);if(timer.current)clearTimeout(timer.current)}},[]);
 return <><div id="sidewalk-home" tabIndex={-1} inert={visible} aria-hidden={visible||undefined}>{children}</div>{visible&&<section className={`arrival-screen ${leaving?'leaving':''}`} aria-label="Welcome to Sidewalk">{index!==null&&<img src={`/arrival-art/${artworks[index]}.png`} alt="" fetchPriority="high"/>}<div className="arrival-wordmark"><h1>sidewalk</h1><p>San Francisco, on foot</p></div><button ref={skip} onClick={dismiss}>Explore <span aria-hidden="true">↗</span></button></section>}</>;
}
