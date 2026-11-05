import {distance, type Fix} from './live-walk';
export function arrivalCheck(fix: Fix, place: {lat:number;lng:number}, now=Date.now()) {
  const values=[fix.lat,fix.lng,fix.accuracy,fix.timestamp,place.lat,place.lng,now];
  if(!values.every(Number.isFinite)||Math.abs(fix.lat)>90||Math.abs(fix.lng)>180||Math.abs(place.lat)>90||Math.abs(place.lng)>180) return {ok:false,message:'Couldn’t confirm your location. Try again.'};
  const age=now-fix.timestamp;
  if(age< -1000||age>15000||fix.accuracy<0||fix.accuracy>35) return {ok:false,message:'GPS is still a little fuzzy. Enable Precise Location and try again outdoors.'};
  const away=distance(fix,place);
  if(away>75||away+fix.accuracy>100) return {ok:false,message:`You’re about ${Math.round(away)} m away. Check in within 75 m from a public path.`};
  return {ok:true,message:'Story unlocked'};
}
