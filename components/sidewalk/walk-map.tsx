'use client';
import {useEffect,useRef,useState} from 'react';
import type {Fix} from '@/lib/live-walk';
import type {Walk} from '@/lib/types';
import type {Map as LibreMap,Marker,GeoJSONSource} from 'maplibre-gl';
import {fieldGuideStyle} from '@/lib/map-style';
import 'maplibre-gl/dist/maplibre-gl.css';
const emptyRoute={type:'FeatureCollection' as const,features:[]};
export default function WalkMap({walk,selected,onSelect,bottomInset=0,visited=[],viewRevision=0,fix=null,following=false,onPan}:{walk:Walk|null;selected:number;onSelect:(n:number)=>void;bottomInset?:number;visited?:number[];viewRevision?:number;fix?:Fix|null;following?:boolean;onPan?:()=>void}){
  const container=useRef<HTMLDivElement>(null),map=useRef<LibreMap|null>(null),library=useRef<typeof import('maplibre-gl')|null>(null);
  const markers=useRef<{marker:Marker;index:number;button:HTMLButtonElement;hide:()=>void}[]>([]);
  const locationMarker=useRef<Marker|null>(null),panCallback=useRef(onPan);panCallback.current=onPan;
  const callback=useRef(onSelect);callback.current=onSelect;
  const [ready,setReady]=useState(false),[error,setError]=useState(false);
  useEffect(()=>{
    setReady(false);
    let cancelled=false,observer:ResizeObserver|undefined;
    const timeout=setTimeout(()=>{if(!cancelled&&!map.current?.isStyleLoaded())setError(true)},20000);
    import('maplibre-gl').then(L=>{
      if(cancelled||!container.current)return;
      L.setWorkerUrl('/map-worker/maplibre-gl-worker.mjs');
      library.current=L;
      const m=new L.Map({container:container.current,style:fieldGuideStyle,center:[-122.409,37.7954],zoom:13.6,minZoom:10,maxZoom:19,attributionControl:false,pitchWithRotate:false});
      map.current=m;m.touchPitch.disable();m.on('dragstart',()=>panCallback.current?.());m.on('zoomstart',e=>{if(e.originalEvent)panCallback.current?.()});
      m.addControl(new L.NavigationControl({showCompass:true,visualizePitch:false}),'top-right');
      m.addControl(new L.AttributionControl({compact:true}),'bottom-right');
      m.on('load',()=>{
        if(cancelled)return;
        clearTimeout(timeout);setError(false);
        m.addSource('walk-route',{type:'geojson',data:emptyRoute});
        m.addLayer({id:'walk-route-halo',type:'line',source:'walk-route',layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':'#fcfaf6','line-width':9}},'major-street-names');
        m.addLayer({id:'walk-route-line',type:'line',source:'walk-route',layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':'#315f8b','line-width':4.5}},'major-street-names');
        setReady(true);
      });
      m.on('error',()=>{if(!m.isStyleLoaded())setError(true)});
      observer=new ResizeObserver(()=>m.resize());observer.observe(container.current);
    }).catch(()=>{if(!cancelled)setError(true)});
    return()=>{cancelled=true;clearTimeout(timeout);observer?.disconnect();markers.current.forEach(({marker,hide})=>{hide();marker.remove()});markers.current=[];locationMarker.current?.remove();locationMarker.current=null;map.current?.remove();map.current=null};
  },[]);
  useEffect(()=>{
    const m=map.current,L=library.current;if(!ready||!m||!L)return;
    markers.current.forEach(({marker,hide})=>{hide();marker.remove()});markers.current=[];
    (m.getSource('walk-route') as GeoJSONSource).setData(walk?{type:'Feature',properties:{},geometry:walk.geometry}:emptyRoute);
    function add(lng:number,lat:number,label:string,title:string,kind:string,index:number){
      const button=document.createElement('button');button.type='button';button.className='map-pin-wrapper';button.title=title;button.setAttribute('aria-label',`${label}: ${title}`);
      const pin=document.createElement('span');pin.className=`map-pin ${kind}`;pin.textContent=label;button.appendChild(pin);
      const marker=new L!.Marker({element:button,anchor:'center'}).setLngLat([lng,lat]).addTo(m!);
      const popup=new L!.Popup({closeButton:false,closeOnClick:false,offset:26,className:'stop-tooltip'}).setText(title);
      const show=()=>popup.setLngLat([lng,lat]).addTo(m!),hide=()=>popup.remove();
      button.addEventListener('mouseenter',show);button.addEventListener('mouseleave',hide);button.addEventListener('focus',show);button.addEventListener('blur',hide);
      button.addEventListener('click',()=>{hide();if(index>=0)callback.current(index)});
      markers.current.push({marker,index,button,hide});
    }
    if(walk){add(walk.start.lng,walk.start.lat,'A',walk.start.name,'endpoint',-1);walk.stops.forEach((p,i)=>add(p.lng,p.lat,String(i+1),p.name,'',i));add(walk.end.lng,walk.end.lat,'B',walk.end.name,'endpoint',walk.stops.length)}
    else{m.jumpTo({center:[-122.409,37.7954],zoom:13.6,bearing:0,padding:{top:0,bottom:0,left:0,right:0}});add(-122.4065,37.7976,'✦','City Lights Bookstore','discovery',-1);add(-122.4044,37.7969,'✦','Sentinel Building','discovery',-1);add(-122.4058,37.8024,'✦','Coit Tower','discovery',-1);add(-122.39372,37.79549,'A','Ferry Building','endpoint',-1)}
    return()=>{markers.current.forEach(({marker,hide})=>{hide();marker.remove()});markers.current=[]};
  },[ready,walk]);
  useEffect(()=>{
    const m=map.current,L=library.current;if(!ready||!walk||!m||!L||following)return;
    m.resize();
    const padding={top:90,bottom:Math.min(bottomInset+32,Math.max(32,m.getContainer().clientHeight-200)),left:44,right:44};
    const duration=window.matchMedia('(prefers-reduced-motion: reduce)').matches?0:350;
    const point=walk.stops[selected]||(selected===walk.stops.length?walk.end:null);
    if(point)m.easeTo({center:[point.lng,point.lat],padding,duration});
    else{const bounds=new L.LngLatBounds();walk.geometry.coordinates.forEach(p=>bounds.extend([p[0],p[1]]));m.fitBounds(bounds,{padding,maxZoom:16,bearing:0,duration})}
  },[ready,walk,selected,bottomInset,viewRevision]);
  useEffect(()=>{markers.current.forEach(({button,index})=>{const pin=button.firstElementChild!;pin.classList.toggle('active',index>=0&&index===selected);pin.classList.toggle('visited',index>=0&&visited.includes(index));button.setAttribute('aria-pressed',String(index>=0&&index===selected))})},[ready,walk,selected,visited]);
  useEffect(()=>{
    const m=map.current,L=library.current;if(!m||!L||!ready)return;
    if(!fix){locationMarker.current?.remove();locationMarker.current=null;return;}
    if(!locationMarker.current){const dot=document.createElement('div');dot.className='live-location-dot';dot.setAttribute('role','img');dot.setAttribute('aria-label','Your current location');locationMarker.current=new L.Marker({element:dot}).addTo(m)}
    locationMarker.current.setLngLat([fix.lng,fix.lat]);locationMarker.current.getElement().title=`Location accuracy: ±${Math.round(fix.accuracy)} m`;
    if(following)m.easeTo({center:[fix.lng,fix.lat],zoom:16.5,bearing:0,padding:{top:90,bottom:Math.min(bottomInset+40,Math.max(40,m.getContainer().clientHeight-200)),left:30,right:30},duration:window.matchMedia('(prefers-reduced-motion: reduce)').matches?0:650});
  },[fix,following,ready,bottomInset,viewRevision]);
  return <><div ref={container} className="vector-map" style={{'--map-bottom-inset':`${bottomInset+4}px`} as React.CSSProperties} aria-label="Interactive walking itinerary map"/>{error&&<div className="map-error" role="status">The map couldn’t load. Your stops and walking directions are still available.</div>}</>;
}
