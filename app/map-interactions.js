(function(){
  'use strict';

  function bindStair(component,el){
    let down=null,opened=false;
    const open=ev=>{
      const idx=Number(el.dataset.lwi),sourceLevel=el.dataset.lwlv||component.curLevel;
      const shape=component._shapeArr('lift',sourceLevel)[idx];
      ev.stopPropagation();ev.preventDefault();
      if(!shape)return;
      if(component._drawingLift){component._shapeMenu('lift',idx,sourceLevel);return;}
      component._openShape(shape,sourceLevel,'stair');
    };
    el.addEventListener('pointerdown',ev=>{
      down=[ev.clientX,ev.clientY];opened=false;ev.stopPropagation();
      if(el.setPointerCapture)try{el.setPointerCapture(ev.pointerId);}catch(_e){}
    });
    el.addEventListener('pointerup',ev=>{
      ev.stopPropagation();
      const moved=down?Math.hypot(ev.clientX-down[0],ev.clientY-down[1]):0;
      down=null;
      if(moved<=10){opened=true;open(ev);}
    });
    el.addEventListener('click',ev=>{
      ev.stopPropagation();ev.preventDefault();
      if(opened){opened=false;return;}
      open(ev);
    });
  }

  window.__RWS_MAP_INTERACTIONS=Object.assign(window.__RWS_MAP_INTERACTIONS||{},{bindStair});
  /* DOM marker is intentionally realm-agnostic: support/debug tooling can
     confirm this small interaction module loaded even when the app runtime
     executes scripts in an isolated JavaScript world. */
  document.documentElement.dataset.rwsMapInteractions='ready';
})();
