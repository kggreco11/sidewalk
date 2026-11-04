import fs from 'node:fs/promises';
const root=new URL('../',import.meta.url);
const manifest=JSON.parse(await fs.readFile(new URL('lib/data/place-images.json',root),'utf8'));
await fs.mkdir(new URL('public/place-covers/',root),{recursive:true});
await fs.mkdir(new URL('ios/Sidewalk/Resources/PlaceCovers/',root),{recursive:true});
for(const [id,item] of Object.entries(manifest)){
 if(!/^[a-zA-Z0-9._-]+$/.test(id))throw Error('Unsafe place ID');
 const remote=item.imageRemote||item.image;
 const existing=(await fs.readdir(new URL('public/place-covers/',root))).find(name=>name.startsWith(id+'.'));
 if(existing){item.imageRemote=remote;item.image=`/place-covers/${existing}`;item.imageLocal=existing;continue}
 const result=await fetch(remote,{headers:{'User-Agent':'SidewalkPrototype/0.1 (licensed place image caching)'},signal:AbortSignal.timeout(30000)});
 if(!result.ok)throw Error(`Photo download ${id}: ${result.status}`);
 const type=result.headers.get('content-type');if(!['image/jpeg','image/png','image/webp'].includes(type))throw Error(`Unsupported image ${id}: ${type}`);
 const suffix={'image/jpeg':'jpg','image/png':'png','image/webp':'webp'}[type];const name=`${id}.${suffix}`;const buffer=Buffer.from(await result.arrayBuffer());
 if(buffer.length>12000000)throw Error(`Oversized photo ${id}`);
 await fs.writeFile(new URL(`public/place-covers/${name}`,root),buffer);
 await fs.writeFile(new URL(`ios/Sidewalk/Resources/PlaceCovers/${name}`,root),buffer);
 item.imageRemote=remote;item.image=`/place-covers/${name}`;item.imageLocal=name;
 await new Promise(resolve=>setTimeout(resolve,1100));
}
await fs.writeFile(new URL('lib/data/place-images.json',root),JSON.stringify(manifest,null,2)+'\n');
console.log(`Cached ${Object.keys(manifest).length} covers for web and iPhone.`);
