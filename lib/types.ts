export type Point={name:string;lat:number;lng:number;address?:string};
export type Place=Point&{id:string;category:string;story:string;facts:string;source:string;sourceName:string;year:number|null;quality:number};
export type Direction={text:string;distance:number};
export type Leg={distance:number;duration:number;steps:Direction[]};
export type Walk={start:Point;end:Point;stops:Place[];geometry:{type:'LineString';coordinates:number[][]};legs:Leg[];distance:number;duration:number;directDuration:number;extraMinutes:number;pauseMinutes:number;title:string;mode:'ai'|'sourced';note:string;generatedAt:string};
