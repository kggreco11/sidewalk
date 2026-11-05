import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {createRequire} from 'node:module';
const output=mkdtempSync(join(tmpdir(),'sidewalk-arrival-'));
try {
 execFileSync(process.execPath,['node_modules/typescript/bin/tsc','lib/arrival.ts','lib/live-walk.ts','lib/types.ts','--outDir',output,'--module','commonjs','--target','es2022','--skipLibCheck']);
 const {arrivalCheck}=createRequire(import.meta.url)(join(output,'arrival.js'));
 const now=1_800_000_000_000,target={lat:37.8,lng:-122.4};
 const fix={...target,accuracy:10,timestamp:now};
 const check=(change={})=>arrivalCheck({...fix,...change},target,now).ok;
 assert.equal(check(),true,'fresh precise arrival unlocks');
 assert.equal(check({lat:37.81}),false,'distant fix does not unlock');
 assert.equal(check({accuracy:36}),false,'imprecise GPS does not unlock even at target');
 assert.equal(check({accuracy:-1}),false,'invalid negative accuracy fails');
 assert.equal(check({timestamp:now-15001}),false,'stale location fails');
 assert.equal(check({timestamp:now+2000}),false,'future location fails');
 assert.equal(check({lat:NaN}),false,'invalid location fails');
 assert.equal(check({lat:91}),false,'out of range latitude fails');
 assert.equal(check({lat:target.lat+70/111195,accuracy:35}),false,'uncertainty crossing outer boundary fails');
 assert.equal(check({lat:target.lat+65/111195,accuracy:20}),true,'reasonable outdoor arrival succeeds');
 console.log('10 arrival verification cases passed');
} finally {rmSync(output,{recursive:true,force:true})}
