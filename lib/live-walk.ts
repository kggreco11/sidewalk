import type {Leg,Point} from './types';
export type Fix={lat:number;lng:number;accuracy:number;timestamp:number};
export function distance(a:{lat:number;lng:number},b:{lat:number;lng:number}){const r=Math.PI/180,x=(b.lng-a.lng)*r*Math.cos((a.lat+b.lat)*r/2),y=(b.lat-a.lat)*r;return Math.hypot(x,y)*6371000}
export function navigation(fix:Fix,target:Point,leg?:Leg,now=Date.now()){
 const direct=distance(fix,target),reliable=now-fix.timestamp<20000&&fix.accuracy<=50;
 let best=Infinity,remaining=0,instruction='',turnDistance=0;
 const steps=leg?.steps||[];
 for(let k=0;k<steps.length;k++){
  const line=steps[k].coordinates||[];
  for(let i=1;i<line.length;i++){
   const a={lat:line[i-1][1],lng:line[i-1][0]},b={lat:line[i][1],lng:line[i][0]};
   const cos=Math.cos(fix.lat*Math.PI/180),ax=(a.lng-fix.lng)*cos,ay=a.lat-fix.lat,bx=(b.lng-fix.lng)*cos,by=b.lat-fix.lat;
   const dx=bx-ax,dy=by-ay,t=Math.max(0,Math.min(1,-(ax*dx+ay*dy)/(dx*dx+dy*dy||1)));
   const p={lat:a.lat+(b.lat-a.lat)*t,lng:a.lng+(b.lng-a.lng)*t},away=distance(fix,p);
   if(away<best){best=away;let rest=distance(p,b);for(let j=i+1;j<line.length;j++)rest+=distance({lat:line[j-1][1],lng:line[j-1][0]},{lat:line[j][1],lng:line[j][0]});turnDistance=rest;remaining=rest+steps.slice(k+1).reduce((sum,s)=>sum+s.distance,0);instruction=steps[k+1]?.text||'Arrive near your next stop';}
  }
 }
 const offRoute=reliable&&best>Math.max(60,fix.accuracy*2)&&Number.isFinite(best);
 return {direct,reliable,nearby:reliable&&direct<=50,offRoute,remaining:!offRoute&&Number.isFinite(best)?remaining:null,instruction,turnDistance};
}
export const metres=(n:number)=>n>=1000?`${(n/1000).toFixed(1)} km`:`${Math.max(0,Math.round(n/10)*10)} m`;
