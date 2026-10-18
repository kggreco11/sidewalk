import type {StyleSpecification,ExpressionSpecification} from 'maplibre-gl';
// Sidewalk's own cartography, using OpenFreeMap's OpenMapTiles vector schema.
// No remote style mutation, sprites, API token, or raster color filter.
const name:ExpressionSpecification=['coalesce',['get','name:en'],['get','name_en'],['get','name:latin'],['get','name']];
const roadFilter:ExpressionSpecification=['all',['==',['geometry-type'],'LineString'],['match',['get','class'],['motorway','trunk','primary','secondary','tertiary','minor','service'],true,false]];
export const fieldGuideStyle:StyleSpecification={
  version:8,name:'Sidewalk / Field guide',
  glyphs:'https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf',
  sources:{city:{type:'vector',url:'https://tiles.openfreemap.org/planet'}},
  layers:[
    {id:'paper',type:'background',paint:{'background-color':'#eeeae1'}},
    {id:'green-cover',type:'fill',source:'city','source-layer':'landcover',filter:['match',['get','class'],['wood','grass'],true,false],paint:{'fill-color':'#dce3d0','fill-opacity':.7}},
    {id:'parks',type:'fill',source:'city','source-layer':'park',paint:{'fill-color':'#d5dfc7','fill-opacity':.8}},
    {id:'green-landuse',type:'fill',source:'city','source-layer':'landuse',filter:['match',['get','class'],['cemetery','pitch','recreation_ground'],true,false],paint:{'fill-color':'#dce3d0'}},
    {id:'water',type:'fill',source:'city','source-layer':'water',paint:{'fill-color':'#c8dce2'}},
    {id:'waterways',type:'line',source:'city','source-layer':'waterway',paint:{'line-color':'#c8dce2','line-width':['interpolate',['linear'],['zoom'],10,1,17,5]}},
    {id:'buildings',type:'fill',source:'city','source-layer':'building',minzoom:14.5,paint:{'fill-color':'#ded8cc','fill-outline-color':'#d3cbbd','fill-opacity':['interpolate',['linear'],['zoom'],14.5,0,16,.65]}},
    {id:'street-edges',type:'line',source:'city','source-layer':'transportation',filter:roadFilter,layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':'#ddd6c9','line-width':['interpolate',['exponential',1.4],['zoom'],10,1,13,3,16,11,19,30]}},
    {id:'streets',type:'line',source:'city','source-layer':'transportation',filter:roadFilter,layout:{'line-cap':'round','line-join':'round'},paint:{'line-color':'#fffdf7','line-width':['interpolate',['exponential',1.4],['zoom'],10,.5,13,2,16,9,19,27]}},
    {id:'walkways',type:'line',source:'city','source-layer':'transportation',minzoom:14,filter:['all',['==',['geometry-type'],'LineString'],['match',['get','class'],['path','pedestrian','steps'],true,false]],paint:{'line-color':'#a6afa1','line-width':['interpolate',['linear'],['zoom'],14,.8,18,2],'line-dasharray':[2,2]}},
    {id:'major-street-names',type:'symbol',source:'city','source-layer':'transportation_name',minzoom:13,filter:['match',['get','class'],['primary','secondary','tertiary','trunk'],true,false],layout:{'symbol-placement':'line','symbol-spacing':350,'text-field':name,'text-font':['Noto Sans Regular'],'text-size':11,'text-max-angle':25},paint:{'text-color':'#68747b','text-halo-color':'#fffdf7','text-halo-width':2}},
    {id:'local-street-names',type:'symbol',source:'city','source-layer':'transportation_name',minzoom:15,filter:['match',['get','class'],['minor','service','path','pedestrian'],true,false],layout:{'symbol-placement':'line','symbol-spacing':300,'text-field':name,'text-font':['Noto Sans Regular'],'text-size':10,'text-max-angle':25},paint:{'text-color':'#7b817f','text-halo-color':'#fffdf7','text-halo-width':1.5}},
    {id:'neighborhoods',type:'symbol',source:'city','source-layer':'place',minzoom:11,maxzoom:16.5,filter:['match',['get','class'],['suburb','neighbourhood','quarter'],true,false],layout:{'text-field':name,'text-font':['Noto Sans Regular'],'text-transform':'uppercase','text-letter-spacing':.15,'text-max-width':9,'text-padding':28,'text-size':['interpolate',['linear'],['zoom'],11,10,14,13,16,14]},paint:{'text-color':'#506576','text-halo-color':'#f6f3ed','text-halo-width':2}},
    {id:'city-names',type:'symbol',source:'city','source-layer':'place',maxzoom:11,filter:['==',['get','class'],'city'],layout:{'text-field':name,'text-font':['Noto Sans Regular'],'text-size':16,'text-letter-spacing':.08},paint:{'text-color':'#506576','text-halo-color':'#f6f3ed','text-halo-width':2}},
    {id:'water-names',type:'symbol',source:'city','source-layer':'water_name',filter:['==',['geometry-type'],'Point'],layout:{'text-field':name,'text-font':['Noto Sans Italic'],'text-size':13,'text-letter-spacing':.1,'text-max-width':8},paint:{'text-color':'#6f8a96','text-halo-color':'#c8dce2','text-halo-width':1}},
  ]
};
