'use client';
import {Lock,Navigation} from 'lucide-react';
import type {useArrival} from './use-arrival';
export default function LockedStory({place,arrival}:{place:{id:string;lat:number;lng:number};arrival:ReturnType<typeof useArrival>}){
 return <section className="locked-story"><h3><Lock size={20}/>Field notes locked</h3><p>Visit this spot to unlock its field notes. Check in within 75 m from a public path.</p><button className="primary-action" disabled={!!arrival.pending} onClick={()=>void arrival.verify(place)}>{arrival.pending===place.id?'Checking location…':'I’m here · unlock story'}<Navigation size={20}/></button>{arrival.error?.id===place.id&&<p role="alert">{arrival.error.message}</p>}<small>Location is checked on your device.</small></section>
}
