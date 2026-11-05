import fs from 'node:fs/promises';
const matches=JSON.parse(await fs.readFile(new URL('../data/place-image-matches.json',import.meta.url),'utf8'));
const clean=value=>String(value||'').replace(/<[^>]*>/g,'').replace(/&amp;/g,'&').replace(/&quot;/g,'"').replace(/&#39;/g,"'").replace(/&nbsp;/g,' ').trim();
const images={};const rejected=[];
for(const match of matches){
 const params=new URLSearchParams({action:'query',format:'json',prop:'imageinfo',iiprop:'url|extmetadata',iiurlwidth:'800',titles:match.file});
 const response=await fetch('https://commons.wikimedia.org/w/api.php?'+params,{headers:{'User-Agent':'SidewalkPrototype/0.1 (https://github.com/kggreco11/sidewalk; image metadata import)'},signal:AbortSignal.timeout(30000)});
 if(!response.ok)throw new Error(`Commons ${response.status} for ${match.file}`);
 const result=await response.json();const info=Object.values(result.query?.pages||{})[0]?.imageinfo?.[0];const metadata=info?.extmetadata||{};
 const license=clean(metadata.LicenseShortName?.value);const artist=clean(metadata.Artist?.value);
 if(!info?.thumburl||!artist||!(/^(CC BY(?:-SA)? [1-4]\.0|CC0|Public domain)/i.test(license))){rejected.push({id:match.id,reason:'Missing usable image, author, or supported license',license});continue}
 images[match.id]={image:info.thumburl,imageCredit:`${artist} · ${license}`,imageAuthor:artist,imageLicense:license,imageLicenseUrl:metadata.LicenseUrl?.value||null,imageSource:info.descriptionurl,imageDescription:clean(metadata.ImageDescription?.value),imageDate:clean(metadata.DateTimeOriginal?.value),imageRetrievedAt:new Date().toISOString(),wikidata:match.wikidata};
 await new Promise(resolve=>setTimeout(resolve,1100));
}
await fs.writeFile(new URL('../data/place-images.json',import.meta.url),JSON.stringify(images,null,2)+'\n');
await fs.writeFile(new URL('../data/place-images-rejected.json',import.meta.url),JSON.stringify(rejected,null,2)+'\n');
console.log(`${Object.keys(images).length} licensed place images; ${rejected.length} rejected.`);
