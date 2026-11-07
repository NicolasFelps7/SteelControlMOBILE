(function(root){'use strict';
const T=root.THREE,M=root.SteelMachineModels;
function create(container,options={}) {
 let disposed=false,frame=0,dirty=false,lastDraw=0,selected=null,wire=false,intersecting=true;
 let yaw=.8,pitch=.82,radius=14,defaultRadius=14;const target=new T.Vector3(0,1,0),models=new Map(),pointers=new Map();let drag=null,pinch=0;
 container.classList.add('steel3d');const stage=document.createElement('div');stage.className='steel3d-stage';container.append(stage);
 const status=document.createElement('div');status.className='steel3d-status';status.setAttribute('role','status');container.append(status);
 const labels=document.createElement('div');labels.className='steel3d-labels';container.append(labels);
 const toolbar=document.createElement('div');toolbar.className='steel3d-tools';container.append(toolbar);
 let renderer;try{renderer=new T.WebGLRenderer({antialias:true,alpha:false,powerPreference:'low-power'});}catch(error){status.textContent='3D indisponível: confira a aceleração gráfica / Android System WebView.';options.onError?.('WEBGL_UNAVAILABLE');return{update(){},focus(){},dispose(){container.replaceChildren();}};}
 renderer.setPixelRatio(Math.min(root.devicePixelRatio||1,options.mobile?1.25:1.5));renderer.outputEncoding=T.sRGBEncoding;renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.25;renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;stage.append(renderer.domElement);
 const scene=new T.Scene();scene.background=new T.Color(0x131e26);const camera=new T.PerspectiveCamera(42,1,.1,400);const ambient=new T.HemisphereLight(0xdceeff,0x26323a,1.25);scene.add(ambient);
 const sun=new T.DirectionalLight(0xffedd3,2);sun.position.set(10,22,14);sun.castShadow=true;sun.shadow.mapSize.set(options.mobile?512:1024,options.mobile?512:1024);sun.shadow.camera.left=-45;sun.shadow.camera.right=45;sun.shadow.camera.top=45;sun.shadow.camera.bottom=-45;sun.shadow.bias=-.0005;scene.add(sun);const rim=new T.DirectionalLight(0x94abc0,.6);rim.position.set(-10,12,-15);scene.add(rim);
 const floor=new T.Mesh(new T.PlaneGeometry(160,160),new T.MeshStandardMaterial({color:0x34434c,roughness:.84,metalness:.18}));floor.rotation.x=-Math.PI/2;floor.receiveShadow=true;floor.position.y=-.035;scene.add(floor);
 const grid=new T.GridHelper(140,70,0x76838c,0x4b5963);grid.position.y=-.025;scene.add(grid);
 const highlight=new T.Mesh(new T.TorusGeometry(3,.028,6,64),new T.MeshBasicMaterial({color:0xffb34e}));highlight.rotation.x=-Math.PI/2;highlight.position.y=.025;highlight.visible=false;scene.add(highlight);
 const wireMaterial=new T.MeshBasicMaterial({color:0xf0a448,wireframe:true});
 const factory=new T.Group();scene.add(factory);const decoGeometry=new T.BoxGeometry(1,1,1),decoMaterials={metal:new T.MeshStandardMaterial({color:0x3f505b,metalness:.55,roughness:.52}),amber:new T.MeshStandardMaterial({color:0xb67d23,roughness:.8}),pad:new T.MeshStandardMaterial({color:0x28363e,roughness:.9}),light:new T.MeshBasicMaterial({color:0xa6bdc7})};let layoutSignature='',infrastructure=null,plantMode=options.factoryScene===true;
 function block(x,y,z,w,h,d,material){const n=new T.Mesh(decoGeometry,decoMaterials[material]);n.position.set(x,y,z);n.scale.set(w,h,d);n.receiveShadow=true;n.castShadow=material==='metal';factory.add(n);}
 function decorate(columns,rows,count){const signature=`${columns}:${rows}:${count}:${plantMode}`;if(signature===layoutSignature)return;layoutSignature=signature;factory.clear();if(infrastructure){scene.remove(infrastructure.group);infrastructure.dispose();infrastructure=null;}if(plantMode&&count&&root.SteelFactoryContext){infrastructure=root.SteelFactoryContext.build({columns,rows,count});scene.add(infrastructure.group);}const w=Math.max(12,columns*8+4),depth=Math.max(11,rows*7+4),back=-depth/2-1;
  for(let i=0;i<count;i++){const x=(i%columns-(columns-1)/2)*8,z=(Math.floor(i/columns)-(rows-1)/2)*7;block(x,-.012,z,6.7,.025,5.4,'pad');for(const side of [-1,1]){block(x+side*3.4,.015,z,.055,.025,5.8,'amber');block(x,.015,z+side*2.85,6.85,.025,.055,'amber');}for(let k=0;k<8;k++){const strip=new T.Mesh(decoGeometry,decoMaterials.amber);strip.position.set(x-2.8+k*.8,.02,z+2.48);strip.scale.set(.4,.026,.10);strip.rotation.y=-Math.PI/4;factory.add(strip);}}
  // Estrutura de galpão e corredores delimitados, sem sugerir uma planta medida.
  block(0,2.1,back,w+4,4.2,.18,'pad');for(const x of [-w/2,w/2]){block(x,3,back,.2,6,.25,'metal');block(x,3,depth/2,.2,6,.25,'metal');block(x,6,0,.2,.25,depth+2,'metal');}
  for(const z of [back,depth/2]){block(0,6,z,w,.25,.2,'metal');block(0,5.82,z,w*.75,.035,.10,'light');}
  for(let x=-w/2;x<=w/2;x+=2){block(x,.65,back+1,.055,1.3,.055,'amber');}for(const y of [.2,.7,1.25])block(0,y,back+1,w,.04,.04,'amber');
  for(const side of [-1,1])block(side*(w/2-.5),.01,0,.07,.02,depth,'amber');
 }

 const axes=new T.Group();scene.add(axes);for(const [direction,color]of [[new T.Vector3(1,0,0),0xe37363],[new T.Vector3(0,0,1),0x70bd93],[new T.Vector3(0,1,0),0x6aa4dd]])axes.add(new T.ArrowHelper(direction,new T.Vector3(-2,.06,2),.85,color,.15,.07));
 const ray=new T.Raycaster(),mouse=new T.Vector2();
 function setStatus(text){status.textContent=text;status.hidden=!text;}
 function render(ts){frame=0;if(disposed||!dirty||document.hidden||!intersecting)return;if(ts-lastDraw<32){frame=requestAnimationFrame(render);return;}lastDraw=ts;dirty=false;let moving=false;for(const row of models.values())moving=M.advance(row.group,ts)||moving;
  camera.position.set(target.x+radius*Math.sin(yaw)*Math.cos(pitch),target.y+radius*Math.sin(pitch),target.z+radius*Math.cos(yaw)*Math.cos(pitch));camera.lookAt(target);scene.overrideMaterial=wire?wireMaterial:null;renderer.render(scene,camera);
  for(const row of models.values()){const point=row.anchor.clone().add(row.group.position).project(camera);const visible=point.z>=-1&&point.z<=1&&Math.abs(point.x)<1.1&&Math.abs(point.y)<1.1;row.label.hidden=!visible;if(visible){row.label.style.left=`${(point.x*.5+.5)*100}%`;row.label.style.top=`${(-point.y*.5+.5)*100}%`;}
   if(row.jointLabels?.length){const joints=row.group.userData.joints,parts=[joints.yaw,joints.shoulder,joints.elbow,joints.wrist];row.jointLabels.forEach((item,i)=>{const p=parts[i].getWorldPosition(new T.Vector3()).project(camera),measured=row.machine?.joints?.[item.key];item.node.hidden=row.machine?.id!==selected||p.z< -1||p.z>1;if(!item.node.hidden){item.node.textContent=`${item.key.toUpperCase()} ${row.machine.online&&!row.machine.simulacao&&typeof measured==='number'?measured.toFixed(1)+'°':'—'}`;item.node.style.left=`${(p.x*.5+.5)*100}%`;item.node.style.top=`${(-p.y*.5+.5)*100}%`;}});}
  }
  if(moving)invalidate();
 }
 function invalidate(){if(disposed)return;dirty=true;if(!frame&&!document.hidden&&intersecting)frame=requestAnimationFrame(render);}
 function size(){const rect=container.getBoundingClientRect();if(rect.width<2||rect.height<2)return;renderer.setSize(rect.width,rect.height,false);camera.aspect=rect.width/rect.height;camera.updateProjectionMatrix();invalidate();}
 function focus(id,detail=false){const row=models.get(Number(id));if(!row)return;target.copy(row.group.position);target.y=1;radius=Math.max(plantMode&&!detail?9:5,row.bounds.getSize(new T.Vector3()).length()*(plantMode&&!detail?1.6:1.25));if(plantMode&&!detail){pitch=.64;yaw=.68;}invalidate();}
 function reset(){target.set(0,1,0);yaw=.8;pitch=.82;radius=defaultRadius;invalidate();}
 const actions=[['+','Aproximar',()=>{radius=Math.max(3,radius*.82);invalidate();}],['−','Afastar',()=>{radius=Math.min(120,radius*1.22);invalidate();}],['⌂','Visão geral',reset],['◎','Focar seleção',()=>focus(selected,true)],['◇','Malha 3D',()=>{wire=!wire;invalidate();}]];
 for(const [text,title,action]of actions){const b=document.createElement('button');b.type='button';b.textContent=text;b.title=title;b.setAttribute('aria-label',title);b.addEventListener('click',action);toolbar.append(b);}
 function normalized(raw){if(!Array.isArray(raw))return[];const ids=new Set();return raw.slice(0,100).filter(m=>m&&Number.isSafeInteger(m.id)&&m.id>0&&!ids.has(m.id)&&ids.add(m.id)).map(m=>({id:m.id,nome:String(m.nome||'').slice(0,100),tipo:String(m.tipo||'').slice(0,120),modelo:String(m.modelo||'').slice(0,120),controlador:String(m.controlador||'').slice(0,120),simulacao:m.simulacao===true,online:m.online===true,joints:m.joints&&typeof m.joints==='object'?Object.fromEntries(['j1','j2','j3','j4'].filter(k=>typeof m.joints[k]==='number'&&Number.isFinite(m.joints[k])&&Math.abs(m.joints[k])<=360).map(k=>[k,m.joints[k]])):null}));}
 function update(state={}) {
  plantMode=options.factoryScene===true||state.factoryScene===true;
  const data=normalized(state.machines),max=options.mobile?12:24,shown=data.slice(0,max);const nextId=Number.isSafeInteger(state.selectedId)?state.selectedId:null;
  if(nextId&&!shown.some(m=>m.id===nextId)){const item=data.find(m=>m.id===nextId);if(item){if(shown.length>=max)shown.pop();shown.push(item);}}
  const keep=new Set(shown.map(m=>m.id));let changed=false;
  for(const [id,row]of models)if(!keep.has(id)){scene.remove(row.group);M.dispose?.(row.group);row.label.remove();row.jointLabels?.forEach(j=>j.node.remove());models.delete(id);changed=true;}
  for(const machine of shown){const kind=M.classify(machine);let row=models.get(machine.id);if(row&&row.kind!==kind){scene.remove(row.group);M.dispose?.(row.group);row.label.remove();row.jointLabels?.forEach(j=>j.node.remove());models.delete(machine.id);row=null;}
   if(!row){const group=M.build(machine),bounds=new T.Box3().setFromObject(group);const label=document.createElement('button');label.type='button';label.className='steel3d-label';label.addEventListener('click',()=>options.onSelect?.(machine.id));labels.append(label);const jointLabels=group.userData.joints?['j1','j2','j3','j4'].map(key=>{const n=document.createElement('span');n.className='steel3d-joint';n.hidden=true;labels.append(n);return{key,node:n};}):[];row={group,bounds,kind,label,jointLabels,anchor:new T.Vector3(0,bounds.max.y+.35,0)};models.set(machine.id,row);scene.add(group);changed=true;}
   row.machine=machine;row.label.textContent=machine.nome;row.label.title=M.kinds.find(k=>k[0]===kind)?.[1]||'';row.label.classList.toggle('online',machine.online&&!machine.simulacao);row.label.classList.toggle('selected',machine.id===nextId);M.applyState(row.group,machine,true);
  }
  const columns=Math.max(1,Math.ceil(Math.sqrt(shown.length))),rows=Math.ceil(shown.length/columns);shown.forEach((m,i)=>{models.get(m.id).group.position.set((i%columns-(columns-1)/2)*8,0,(Math.floor(i/columns)-(rows-1)/2)*7);});defaultRadius=Math.max(10,columns*7.5+rows*1.5);decorate(columns,rows,shown.length);
  const old=selected;selected=nextId;const row=models.get(selected);highlight.visible=Boolean(row);if(row){highlight.position.x=row.group.position.x;highlight.position.z=row.group.position.z;}
  if(!shown.length)setStatus(state.emptyText||'Cadastre um equipamento para visualizar em 3D.');else setStatus(data.length>max?`${shown.length}/${data.length} · use o seletor para os demais equipamentos`:state.caption||'Arraste para girar · pinça/roda para zoom');
  if(old!==selected&&selected)focus(selected);else if(changed)reset();invalidate();
 }
 const down=e=>{if(e.button===2)e.preventDefault();renderer.domElement.setPointerCapture?.(e.pointerId);pointers.set(e.pointerId,{x:e.clientX,y:e.clientY});if(pointers.size===1)drag={x:e.clientX,y:e.clientY,lastX:e.clientX,lastY:e.clientY,moved:0,pan:e.button===2};if(pointers.size===2){const [a,b]=[...pointers.values()];pinch=Math.hypot(a.x-b.x,a.y-b.y);}};
 const move=e=>{if(!pointers.has(e.pointerId))return;pointers.set(e.pointerId,{x:e.clientX,y:e.clientY});if(pointers.size===2){const[a,b]=[...pointers.values()],next=Math.hypot(a.x-b.x,a.y-b.y);if(pinch>0)radius=T.MathUtils.clamp(radius*pinch/Math.max(next,1),3,120);pinch=next;if(drag)drag.moved=100;invalidate();return;}if(!drag)return;const dx=e.clientX-drag.lastX,dy=e.clientY-drag.lastY;drag.moved+=Math.abs(dx)+Math.abs(dy);drag.lastX=e.clientX;drag.lastY=e.clientY;if(drag.pan){target.x-=dx*radius*.001;target.z+=dy*radius*.001;}else{yaw-=dx*.006;pitch=T.MathUtils.clamp(pitch+dy*.006,.10,1.48);}invalidate();};
 const up=e=>{const click=drag&&drag.moved<7&&pointers.size===1;const rect=renderer.domElement.getBoundingClientRect();pointers.delete(e.pointerId);if(!pointers.size)drag=null;if(click){mouse.set((e.clientX-rect.left)/rect.width*2-1,-(e.clientY-rect.top)/rect.height*2+1);ray.setFromCamera(mouse,camera);const hits=ray.intersectObjects([...models.values()].map(row=>row.group),true);if(hits.length){let node=hits[0].object;while(node&&!node.userData.machineId)node=node.parent;if(node)options.onSelect?.(node.userData.machineId);}}};
 const cancel=e=>{pointers.delete(e.pointerId);drag=null;pinch=0;};
 const wheel=e=>{e.preventDefault();radius=T.MathUtils.clamp(radius*Math.exp(e.deltaY*.001),3,120);invalidate();};const menu=e=>e.preventDefault();const lose=e=>{e.preventDefault();setStatus('Contexto 3D interrompido. Aguarde ou reabra a visualização.');};const restore=()=>{setStatus('');invalidate();};const visible=()=>{if(!document.hidden)invalidate();};
 renderer.domElement.addEventListener('pointerdown',down);renderer.domElement.addEventListener('pointermove',move);renderer.domElement.addEventListener('pointerup',up);renderer.domElement.addEventListener('pointercancel',cancel);renderer.domElement.addEventListener('wheel',wheel,{passive:false});renderer.domElement.addEventListener('contextmenu',menu);renderer.domElement.addEventListener('webglcontextlost',lose);renderer.domElement.addEventListener('webglcontextrestored',restore);document.addEventListener('visibilitychange',visible);
 const observer=new ResizeObserver(size);observer.observe(container);const intersection=new IntersectionObserver(entries=>{intersecting=entries[0]?.isIntersecting!==false;if(intersecting)invalidate();});intersection.observe(container);size();update();
 return{update,focus,reset,dispose(){if(disposed)return;disposed=true;cancelAnimationFrame(frame);observer.disconnect();intersection.disconnect();document.removeEventListener('visibilitychange',visible);for(const row of models.values())M.dispose?.(row.group);infrastructure?.dispose();scene.clear();floor.geometry.dispose();floor.material.dispose();grid.geometry.dispose();grid.material.dispose();highlight.geometry.dispose();highlight.material.dispose();wireMaterial.dispose();axes.traverse(node=>{node.geometry?.dispose();if(Array.isArray(node.material))node.material.forEach(m=>m.dispose());else node.material?.dispose();});decoGeometry.dispose();Object.values(decoMaterials).forEach(m=>m.dispose());renderer.dispose();renderer.forceContextLoss();container.replaceChildren();}};
}
root.SteelMachine3D={create};
if(document.getElementById('steel3d-root')){
 const emit=data=>{if(root.SteelBridge?.postMessage)root.SteelBridge.postMessage(JSON.stringify(data));};
 const engine=create(document.getElementById('steel3d-root'),{mobile:true,onSelect:id=>emit({type:'select',id}),onError:code=>emit({type:'error',code})});
 root.Steel3D={setState:data=>engine.update(data),dispose:()=>engine.dispose()};emit({type:'ready'});
 root.addEventListener('pagehide',()=>engine.dispose());
}
})(typeof globalThis!=='undefined'?globalThis:window);
