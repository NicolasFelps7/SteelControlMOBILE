/* SteelControl: geometria 3D procedural por família. Unidades visuais, não CAD certificado. */
(function(root){'use strict';
const T=root.THREE, clean=s=>String(s||'').normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
const kinds=[['dobot','Dobot Magician'],['robot','Robô industrial'],['conveyor','Esteira industrial'],['injection','Injetora'],['cnc','Fresadora CNC'],['lathe','Torno CNC'],['press','Prensa hidráulica'],['printer','Impressora 3D'],['packer','Embaladora'],['filler','Envasadora'],['welder','Célula de solda'],['compressor','Compressor'],['furnace','Forno industrial'],['plc','Painel CLP'],['generic','Outro equipamento']];
function classify(machine={}) {
 const type=clean(machine.tipo||machine.type), controller=clean(machine.controlador||machine.controller);
 const resolve=text=>{if(/dobot|magician/.test(text))return'dobot';if(/impressora.*3d|3d.*print/.test(text))return'printer';if(/injet|inject/.test(text))return'injection';if(/esteira|conveyor/.test(text))return'conveyor';if(/torno|lathe/.test(text))return'lathe';if(/fresa|cnc|machining/.test(text))return'cnc';if(/prensa|hydraulic.?press|\bpress\b/.test(text))return'press';if(/embala|packag|packer/.test(text))return'packer';if(/envasa|fill/.test(text))return'filler';if(/solda|weld/.test(text))return'welder';if(/compress/.test(text))return'compressor';if(/forno|furnace|oven/.test(text))return'furnace';if(/robo|robot|braco/.test(text))return'robot';if(/clp|plc|painel/.test(text))return'plc';return null;};
 const explicit=resolve(type);if(explicit)return explicit==='robot'&&/dobot/.test(controller)?'dobot':explicit;
 return resolve(clean(`${machine.modelo||''} ${machine.nome||''}`))||resolve(controller)||'generic';
}
const mats={};function material(name,color,metal=.3,rough=.48){return mats[name]||(mats[name]=new T.MeshStandardMaterial({color,metalness:metal,roughness:rough}));}
const colors={amber:0xe78c14,dark:0x27323a,body:0x56656c,steel:0xaeb9bf,black:0x111a20,glass:0x274e60,red:0xbc4343,green:0x62c784};
function mat(name){const m=material(name,colors[name]??0x74828a,name==='steel'?.72:.25);if(name==='glass'){m.transparent=true;m.opacity=.19;m.depthWrite=false;m.metalness=.1;}return m;}
const boxGeo=new T.BoxGeometry(1,1,1), cylGeo=new T.CylinderGeometry(1,1,1,24), sphereGeo=new T.SphereGeometry(1,20,14);
function mesh(parent,geometry,name,x,y,z,sx,sy,sz){const m=new T.Mesh(geometry,mat(name));m.position.set(x,y,z);m.scale.set(sx,sy,sz);m.castShadow=true;m.receiveShadow=true;parent.add(m);return m;}
function box(g,x,y,z,w,h,d,c='body'){return mesh(g,boxGeo,c,x,y,z,w,h,d);}
function cyl(g,x,y,z,r,h,c='steel',axis='y'){const m=mesh(g,cylGeo,c,x,y,z,r,h,r);if(axis==='x')m.rotation.z=Math.PI/2;if(axis==='z')m.rotation.x=Math.PI/2;return m;}
function ball(g,x,y,z,r,c='dark'){return mesh(g,sphereGeo,c,x,y,z,r,r,r);}
function beam(g,a,b,r,c='amber'){const start=new T.Vector3(...a),end=new T.Vector3(...b),m=cyl(g,0,0,0,r,start.distanceTo(end),c);m.position.copy(start.add(end).multiplyScalar(.5));m.quaternion.setFromUnitVectors(new T.Vector3(0,1,0),end.sub(new T.Vector3(...a)).normalize());return m;}
function feet(g,w=2,d=1.6){for(const x of [-w/2,w/2])for(const z of [-d/2,d/2]){cyl(g,x,.12,z,.12,.24,'black');box(g,x,.45,z,.10,.75,.1,'steel');}}
function station(g,w=2.4,d=2){feet(g,w-.3,d-.3);box(g,0,.82,0,w,.15,d,'steel');box(g,0,.55,0,w-.2,.4,d-.2,'dark');}
function lamp(g,x,y,z){const lights=[cyl(g,x,y,z,.075,.17,'dark'),cyl(g,x,y-.16,z,.075,.12,'dark'),cyl(g,x,y-.28,z,.075,.12,'dark')];(g.userData.statusLamps??=[]).push(lights);}
function cabinet(g,x=0,z=0){box(g,x,1.02,z,1,2,.65,'body');box(g,x,1.03,z+.34,.91,1.9,.025,'dark');box(g,x+.31,1.04,z+.38,.04,.32,.04,'steel');box(g,x-.12,1.5,z+.38,.48,.32,.035,'black');box(g,x-.12,1.5,z+.404,.39,.24,.015,'glass');for(let i=0;i<4;i++)cyl(g,x-.22+i*.14,1.17,z+.4,.035,.025,i===0?'red':'green','z');for(let i=0;i<6;i++)box(g,x,.45+i*.065,z+.37,.65,.025,.02,'steel');lamp(g,x+.32,2.24,z);}
function robot(g,dobot=false){
 if(!dobot)station(g,2,1.8);const base=dobot?0:.9,upper=dobot?1.35:1.15,lower=dobot?1.47:1.1;box(g,0,base+.1,0,dobot?1.15:1.25,.2,dobot?.9:1.1,'body');cyl(g,0,base+.3,0,.38,.3,'dark');
 const yaw=new T.Group();yaw.position.y=base+.42;g.add(yaw);cyl(yaw,0,0,0,.3,.16,'amber');const shoulder=new T.Group();shoulder.position.set(0,.25,0);yaw.add(shoulder);ball(shoulder,0,0,0,.24,'dark');beam(shoulder,[0,0,0],[0,upper,0],.17);if(dobot){beam(shoulder,[-.19,.02,.02],[-.19,upper,.02],.055,'steel');beam(shoulder,[.19,.02,.02],[.19,upper,.02],.055,'steel');}
 const elbow=new T.Group();elbow.position.y=upper;shoulder.add(elbow);ball(elbow,0,0,0,.21,'amber');beam(elbow,[0,0,0],[lower,0,0],.145);if(dobot)beam(elbow,[.02,.14,0],[lower-.02,.14,0],.045,'steel');
 const wrist=new T.Group();wrist.position.x=lower;elbow.add(wrist);ball(wrist,0,0,0,.16,'dark');cyl(wrist,.1,-.2,0,.10,.36,'steel');box(wrist,.1,-.42,-.1,.08,.2,.09,'dark');box(wrist,.1,-.42,.1,.08,.2,.09,'dark');cyl(wrist,.1,-.48,0,.13,.04,'black');
 shoulder.rotation.z=-.48;elbow.rotation.z=-.45;g.userData.joints={yaw,shoulder,elbow,wrist};g.userData.jointBase={shoulder:-.48,elbow:-.45};lamp(g,-.4,base+.48,.32);
}
function conveyor(g){feet(g,4.3,1.2);box(g,0,.95,0,4.8,.22,1.5,'dark');for(const z of [-.78,.78])box(g,0,1.1,z,5,.18,.08,'steel');for(let i=0;i<18;i++)cyl(g,-2.25+i*.265,1.08,0,.085,1.4,'steel','z');for(const x of [-.9,.9]){box(g,x,1.34,0,.6,.4,.62,'body');box(g,x,1.56,0,.61,.025,.63,'amber');}box(g,-2.1,.68,1,.5,.4,.4,'body');cyl(g,-2.1,.68,1.25,.13,.3,'dark','z');lamp(g,2.05,1.65,-.55);}
function injection(g){feet(g,5.1,1.6);box(g,0,.45,0,5.7,.65,1.9,'body');box(g,-1.2,1.45,0,2.65,1.45,1.8,'dark');box(g,-1.2,1.52,.92,2.35,1.05,.04,'glass');box(g,-2.45,1.48,0,.2,1.2,1.6,'amber');box(g,.06,1.48,0,.2,1.2,1.6,'amber');for(const y of [1.1,1.88])for(const z of [-.6,.6])cyl(g,-1.2,y,z,.06,2.5,'steel','x');box(g,-1.1,1.48,0,.45,.7,.8,'steel');cyl(g,1.25,1.27,0,.19,2,'steel','x');cyl(g,2.2,1.27,0,.32,.7,'dark','x');const hopper=mesh(g,new T.ConeGeometry(.48,.7,16), 'steel',1.15,2.05,0,1,1,1);hopper.rotation.x=Math.PI;cyl(g,1.15,1.58,0,.12,.3);cabinet(g,2.1,1.25);lamp(g,-2.4,2.45,-.65);}
function cnc(g){feet(g,2.7,2.1);box(g,0,.45,0,3.2,.8,2.5,'body');box(g,0,1.7,-1,3.2,2.1,.35,'body');for(const x of [-1.42,1.42])box(g,x,1.7,0,.3,2.1,2.3,'body');box(g,0,2.7,0,3.2,.22,2.5,'amber');box(g,0,1.4,1.22,2.6,1.75,.03,'glass');for(let i=0;i<6;i++)box(g,0,.95,-.5+i*.22,2,.07,.13,'steel');box(g,0,2.13,-.25,.55,.6,.6,'steel');cyl(g,0,1.68,-.25,.13,.35,'steel');box(g,0,1.08,0,.5,.16,.5,'dark');cabinet(g,2.05,.3);}
function lathe(g){feet(g,3.8,1.5);box(g,0,.6,0,4.4,.8,1.9,'body');box(g,-1.35,1.35,0,1.1,1.4,1.8,'dark');cyl(g,-.7,1.65,0,.4,.35,'steel','x');cyl(g,.25,1.65,0,.12,1.6,'steel','x');for(const z of [-.45,.45])box(g,.5,1.08,z,2.7,.13,.12,'steel');box(g,.4,1.28,.6,.8,.3,.75,'amber');box(g,.4,1.52,.45,.22,.3,.22,'dark');box(g,1.55,1.38,0,.5,.6,.75,'dark');cyl(g,1.2,1.65,0,.14,.5,'steel','x');box(g,0,2.38,0,4.4,.18,1.9,'amber');box(g,0,1.85,-.87,4.4,.9,.1,'body');cabinet(g,2.65,.3);}
function press(g){feet(g,2.1,1.7);box(g,0,.35,0,2.8,.55,2.2,'body');for(const x of [-1,1])for(const z of [-.75,.75])cyl(g,x,1.7,z,.11,2.6,'steel');box(g,0,3,0,2.65,.4,2.1,'amber');cyl(g,0,2.58,0,.35,.6,'dark');cyl(g,0,2.15,0,.18,.5,'steel');box(g,0,1.8,0,2.1,.24,1.7,'amber');box(g,0,.88,0,2.1,.18,1.7,'steel');box(g,0,1.05,0,.8,.2,.7,'dark');lamp(g,-1,3.55,.8);}
function printer(g){station(g,1.8,1.7);for(const x of [-.8,.8])for(const z of [-.7,.7])box(g,x,1.85,z,.09,2,.09,'dark');for(const y of [.95,2.85]){box(g,0,y,-.7,1.7,.08,.08,'amber');box(g,0,y,.7,1.7,.08,.08,'amber');box(g,-.8,y,0,.08,.08,1.5,'amber');box(g,.8,y,0,.08,.08,1.5,'amber');}box(g,0,1.35,0,1.35,.12,1.2,'steel');box(g,0,2.35,0,1.5,.10,.1,'steel');box(g,0,2.22,0,.32,.25,.25,'amber');cyl(g,0,2.01,0,.035,.2,'steel');cyl(g,.8,2.1,-1.02,.4,.2,'dark','z');box(g,-.15,1.56,.1,.45,.3,.45,'amber');}
function packer(g){conveyor(g);for(const x of [-.8,.8])box(g,x,1.8,-.65,.16,1.8,.16,'amber');box(g,0,2.65,0,2,.2,1.8,'amber');box(g,0,2.35,.68,1.45,.45,.2,'body');for(const x of [-.6,.6])cyl(g,x,2.2,-.12,.08,.75,'steel');cyl(g,0,2.84,-.7,.38,1.1,'dark','x');box(g,1.8,1.65,1,.5,.5,.1,'dark');}
function filler(g){conveyor(g);box(g,0,2.5,-.7,3,.5,.75,'steel');for(let i=0;i<4;i++){const x=-.9+i*.6;cyl(g,x,2.04,-.2,.05,.5,'steel');cyl(g,x,1.5,-.2,.16,.65,'glass');cyl(g,x,1.85,-.2,.07,.1,'steel');}for(const x of [-1.35,1.35])box(g,x,1.85,-.7,.15,1.5,.15,'amber');}
function welder(g){robot(g,false);box(g,-1.6,1.08,-.2,1.2,.2,1.4,'steel');for(const z of [-.8,.8])for(const x of [-2.2,2])box(g,x,1.25,z,.07,2.5,.07,'amber');box(g,-.1,2.5,-.8,4.2,.06,.1,'amber');box(g,-2.2,1.4,0,.05,1.8,1.6,'glass');cabinet(g,2.4,-.6);}
function compressor(g){feet(g,2.8,1.2);cyl(g,0,.65,0,.65,3.3,'body','x');for(const x of [-1.65,1.65])ball(g,x,.65,0,.64,'body');box(g,-.55,1.5,0,1.2,.5,.8,'dark');cyl(g,.65,1.55,0,.33,.9,'steel','x');for(let i=0;i<6;i++)box(g,.45+i*.08,1.55,0,.03,.7,.7,'steel');beam(g,[-.4,1.55,0],[.3,1,.25],.04,'steel');cyl(g,1.3,1.45,.1,.17,.08,'black','z');}
function furnace(g){feet(g,2.4,2.1);box(g,0,1.45,0,2.8,2.6,2.5,'body');box(g,0,1.45,1.27,2.3,2.15,.08,'dark');box(g,0,1.45,1.34,1.8,1.6,.06,'amber');box(g,0,1.45,1.39,1.28,1.1,.04,'black');box(g,.8,1.4,1.48,.08,.4,.12,'steel');cyl(g,.7,3.05,-.65,.23,.8,'steel');cabinet(g,1.95,.2);lamp(g,-1,3,1);}
function plc(g){cabinet(g,0,0);box(g,-.6,1,-.1,.15,1.8,.7,'amber');box(g,.6,1,-.1,.15,1.8,.7,'amber');}

function ring(g,x,y,z,r,t,c='steel',axis='y'){const geo=new T.TorusGeometry(r,t,8,32),m=mesh(g,geo,c,x,y,z,1,1,1);if(axis==='y')m.rotation.x=Math.PI/2;if(axis==='x')m.rotation.y=Math.PI/2;return m;}
function bolts(g,x,y,z,r,count=6,axis='z'){for(let i=0;i<count;i++){const a=i*Math.PI*2/count;const dx=axis==='x'?0:Math.cos(a)*r,dy=axis==='y'?0:Math.sin(a)*r,dz=axis==='z'?0:(axis==='x'?Math.cos(a):Math.sin(a))*r;cyl(g,x+dx,y+dy,z+dz,.032,.025,'steel',axis);}}
function cable(g,points,r=.025){const curve=new T.CatmullRomCurve3(points.map(p=>new T.Vector3(...p)));return mesh(g,new T.TubeGeometry(curve,18,r,6,false),'black',0,0,0,1,1,1);}
function vents(g,x,y,z,w,count=8){for(let i=0;i<count;i++)box(g,x,y+i*.07,z,w,.025,.025,'black');}
function robotDetails(g){const j=g.userData.joints;if(!j)return;const upper=j.elbow.position.y,lower=j.wrist.position.x;
 ring(j.yaw,0,.03,0,.31,.025,'steel');for(let i=0;i<3;i++)ring(j.yaw,0,.07+i*.035,0,.27,.012,'dark');
 for(const [part,r]of [[j.shoulder,.25],[j.elbow,.22]]){cyl(part,0,0,.16,r,.12,'body','z');cyl(part,0,0,.235,r*.72,.04,'steel','z');ring(part,0,0,.263,r*.85,.02,'dark','z');bolts(part,0,0,.27,r*.52,6);}
 box(j.shoulder,0,upper*.52,-.065,.34,upper*.76,.23,'amber');box(j.shoulder,0,upper*.52,.09,.26,upper*.70,.08,'body');for(const y of [.25,upper-.22])bolts(j.shoulder,0,y,.15,.09,4);
 box(j.elbow,lower*.5,0,-.04,lower*.75,.26,.26,'amber');box(j.elbow,lower*.5,0,.12,lower*.69,.18,.045,'body');
 cable(j.shoulder,[[.18,.03,-.2],[.32,.2,-.24],[.31,upper*.65,-.2],[.1,upper,-.17]],.032);cable(j.elbow,[[0,.15,-.15],[.25,.3,-.17],[lower*.75,.24,-.16],[lower,.02,-.12]],.025);
 cyl(j.wrist,.1,-.11,0,.16,.12,'dark');ring(j.wrist,.1,-.16,0,.15,.018,'steel');bolts(j.wrist,.1,-.175,0,.11,6,'y');
 for(let i=0;i<4;i++)ring(j.wrist,.1,-.3-i*.035,0,.085,.014,'black');cable(j.wrist,[[.1,.05,-.12],[.28,-.1,-.1],[.22,-.35,0]],.018);
 g.userData.visualDetails=true;
}
function industrialDetails(g,kind){
 if(g.userData.joints)robotDetails(g);
 const bounds=new T.Box3().setFromObject(g),size=bounds.getSize(new T.Vector3());for(const x of [-1,1])for(const z of [-1,1]){const px=x*Math.min(size.x*.35,2.1),pz=z*Math.min(size.z*.32,.9);cyl(g,px,.035,pz,.07,.07,'steel');ring(g,px,.06,pz,.075,.015,'dark');}
 if(['plc','generic'].includes(kind)){vents(g,0,.3,.39,.65,10);bolts(g,0,1.5,.43,.16,4);for(const side of [-1,1])box(g,side*.56,1.05,-.5,.07,1.6,.07,'steel');}
 if(['cnc','injection','lathe','furnace'].includes(kind)){for(const x of [-.16,.16])box(g,x,1.45,size.z/2+.08,.045,.42,.045,'steel');vents(g,bounds.min.x+.4,.3,bounds.max.z+.03,.4,5);}
 if(kind==='cnc'){for(const x of [-.65,.65])box(g,x,1.48,1.25,1.25,1.55,.018,'glass');box(g,0,.88,.5,2.2,.08,1.25,'black');for(let i=0;i<5;i++)box(g,0,1.89+i*.06,-.57,.48,.026,.03,'dark');}
 if(kind==='lathe'){for(let i=0;i<3;i++){const a=i*Math.PI*2/3,m=box(g,-.49,1.65+Math.sin(a)*.26,Math.cos(a)*.26,.12,.17,.16,'dark');m.rotation.x=-a;}for(let i=0;i<8;i++)ring(g,-.6+i*.03,1.65,0,.27,.007,'steel','x');}
 if(kind==='printer'){ring(g,.8,2.1,-1.14,.32,.065,'body','z');for(const x of [-.68,.68])cyl(g,x,1.95,-.6,.025,1.7,'steel');cable(g,[[-.8,2.75,-.6],[-.4,3.1,-.4],[0,2.65,0],[0,2.25,0]],.025);}
 if(['conveyor','packer','filler'].includes(kind)){for(let i=0;i<5;i++)ring(g,-2.1,.68,1.1+i*.045,.14,.012,'steel','z');for(const x of [-1.7,1.7]){box(g,x,1.22,.7,.09,.1,.15,'black');cable(g,[[x,.9,.8],[x,.72,.9],[-2.1,.68,.9]],.018);}}
 if(kind==='press'){for(const x of [-1.2,1.2]){box(g,x,1.65,1.05,.08,1.65,.08,'dark');for(let i=0;i<12;i++)cyl(g,x,1+i*.11,1.105,.014,.012,'glass','z');}for(let i=0;i<6;i++)ring(g,0,2.35+i*.04,0,.19,.015,'black');}
 if(kind==='injection')cable(g,[[1.8,.6,-.5],[2.7,1,-.7],[2.4,1.3,0]],.055);
 if(kind==='compressor'){for(const x of [-1.4,1.4])ring(g,x,.65,0,.55,.025,'steel','x');cable(g,[[-.4,1.6,-.2],[-.2,1.2,-.5],[1,.9,-.4]],.03);}
 if(kind==='furnace'){for(let i=0;i<4;i++)box(g,-1.36,1+i*.3,1.4,.12,.13,.10,'steel');vents(g,.1,2.8,1.3,.9,4);}
 if(kind==='filler'){for(let i=0;i<4;i++){const x=-.9+i*.6;cable(g,[[x,2.5,-.4],[x,2.7,-.15],[x,2.1,-.2]],.025);}}
 g.userData.visualDetails=true;
}

const builders={dobot:g=>robot(g,true),robot:g=>robot(g,false),conveyor,injection,cnc,lathe,press,printer,packer,filler,welder,compressor,furnace,plc,generic:g=>{station(g);cabinet(g,0,-.4);box(g,0,1.15,.4,1.2,.4,.4,'amber');}};
function build(machine={}){const kind=classify(machine),group=new T.Group();group.name=`steel-${kind}`;group.userData={kind,machineId:Number(machine.id)||0};builders[kind](group);industrialDetails(group,kind);return group;}
function applyState(group,machine={},smooth=false){for(const lights of group.userData.statusLamps||[])lights.forEach((light,i)=>light.material=mat(machine.simulacao&&i===1?'amber':machine.online&&!machine.simulacao&&i===0?'green':'dark'));
 const j=group.userData.joints,p=machine.joints;
 if(!machine.online||machine.simulacao){delete group.userData.transition;return;}
 if(!j||!p||typeof p!=='object')return;
 const angle=k=>typeof p[k]==='number'&&Number.isFinite(p[k])&&Math.abs(p[k])<=360?T.MathUtils.degToRad(p[k]):null;
 const a=angle('j1'),b=angle('j2'),c=angle('j3'),d=angle('j4'),changes=[];
 if(a!=null)changes.push([j.yaw.rotation,'y',-a]);if(b!=null)changes.push([j.shoulder.rotation,'z',-b]);
 // Dobot: J2 é medido desde a vertical e J3 desde a horizontal.
 if(c!=null&&b!=null){changes.push([j.elbow.rotation,'z',b-c]);changes.push([j.wrist.rotation,'z',c]);}
 if(d!=null)changes.push([j.wrist.rotation,'y',-d]);
 if(smooth&&changes.some(([rotation,key,value])=>Math.abs(rotation[key]-value)>.00001))group.userData.transition={started:performance.now(),steps:changes.map(([rotation,key,value])=>({rotation,key,from:rotation[key],to:value}))};
 else if(!smooth){delete group.userData.transition;for(const [rotation,key,value]of changes)rotation[key]=value;}
}
function advance(group,now){const t=group.userData.transition;if(!t)return false;const f=Math.min(1,Math.max(0,(now-t.started)/120));for(const step of t.steps)step.rotation[step.key]=step.from+(step.to-step.from)*f;if(f===1)delete group.userData.transition;return f<1;}
function dispose(group){group.traverse(node=>{if(node.geometry&&![boxGeo,cylGeo,sphereGeo].includes(node.geometry))node.geometry.dispose();});}
root.SteelMachineModels={classify,kinds,build,applyState,advance,dispose};
})(typeof globalThis!=='undefined'?globalThis:window);
