/* Service worker: يجلب الصفحة من الشبكة دائماً (بدون كاش) ولا يستخدم النسخة المخزنة إلا عند انقطاع الإنترنت */
const V='ra-v2';
self.addEventListener('install',e=>{self.skipWaiting();e.waitUntil(caches.open(V).then(c=>c.addAll(['/','/icon-192.png','/icon-512.png'])).catch(()=>{}))});
self.addEventListener('activate',e=>{e.waitUntil(caches.keys().then(k=>Promise.all(k.filter(x=>x!==V).map(x=>caches.delete(x)))).then(()=>self.clients.claim()))});
self.addEventListener('fetch',e=>{
 const r=e.request;
 if(r.method!=='GET'||new URL(r.url).origin!==location.origin)return;
 const nav=r.mode==='navigate'||(r.headers.get('accept')||'').includes('text/html');
 e.respondWith(fetch(r,nav?{cache:'no-cache'}:undefined).then(res=>{if(res.ok){const cp=res.clone();caches.open(V).then(c=>c.put(r,cp))}return res}).catch(()=>caches.match(r).then(m=>m||caches.match('/'))));
});
