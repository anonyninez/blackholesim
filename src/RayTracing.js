import React, { useRef, useEffect } from "react";
import * as THREE from "three";
// eslint-disable-next-line import/no-webpack-loader-syntax
import shader from '!!raw-loader!./shader.glsl';  

const RayTracing = () => {
  function rot2(vFocusPos, r, t1, t2){
    const theta = t1 * Math.PI;
    const phi = (t2 * Math.PI) / 2;
    const x = vFocusPos.x + r * Math.sin(phi) * Math.cos(theta);
    const y = vFocusPos.y + r * Math.cos(phi);
    const z = vFocusPos.z + r * Math.sin(phi) * Math.sin(theta);
    return new THREE.Vector3(x,y,z);
  }

  const mountRef = useRef(null);
  const rayBounces = 100;

  let cameraRadius = .7;
  let mouseX = 0.73; // .5
  let mouseY = .9; // 1.
  let frameCount = 0;

  const fpsDisplay = document.createElement('div');
        fpsDisplay.style.position = 'absolute';
        fpsDisplay.style.top = '10px';
        fpsDisplay.style.left = '10px';
        fpsDisplay.style.color = '#fff';
        fpsDisplay.style.fontFamily = 'monospace';
        fpsDisplay.style.fontSize = '16px';
        document.body.appendChild(fpsDisplay);
  let fps = [0];
  let fpsIdx = 0;
  let lastFrameTime = performance.now();
  useEffect(() => {
    const width = window.innerWidth;
    const height = window.innerHeight;
    const contextAttributes = { lowLatency: false, powerPreference: 'low-power' };
    const renderer = new THREE.WebGLRenderer({contextAttributes});

    let accumulationTarget = new THREE.WebGLRenderTarget(width, height);
    let renderTarget = new THREE.WebGLRenderTarget(width, height);
    
    const spaceHDRI = new THREE.TextureLoader().load('./hdri_milkyway.png')
    spaceHDRI.mapping = THREE.EquirectangularReflectionMapping;

    renderer.setSize(width, height);
    mountRef.current.appendChild(renderer.domElement);

    const camera = new THREE.Camera();
    const scene = new THREE.Scene();

    const material = new THREE.ShaderMaterial({
      fragmentShader: shader,
      uniforms: {
        u_resolution: { value: new THREE.Vector2(width, height) },
        u_focusPos: { value: new THREE.Vector3(0.0, 0.0, 0.0) },
        u_cameraPos: { value: new THREE.Vector3(0.0, 0.0, cameraRadius) },
        u_frameCount: { value: 1 },
        u_time: { value: 0.0 },
        u_rayBounces: { value: rayBounces },
        u_buffer: { value: null },
        u_cameraRadius: {value: cameraRadius},
        u_space: {value: spaceHDRI},
        u_seed: {value: new THREE.Vector3(Math.random(), Math.random(), Math.random())}
      },
    });

    const geometry = new THREE.PlaneGeometry(2, 2);
    const mesh = new THREE.Mesh(geometry, material);
    scene.add(mesh);

    const onMouseMove = (e) => {
      frameCount = 1;
      mouseX = (e.clientX / width) * 2 - 1.5;
      mouseY = (e.clientY / height) * 2 - 2;
    };

    const onWheel = (e) => {
      if (e.shiftKey){
        // rayBounces -= e.deltaY / 100;
        // if(rayBounces < 1) rayBounces = 1;
        // console.log(rayBounces);
        cameraRadius += e.deltaY / 6000;
      }else{
        cameraRadius += e.deltaY / 1000;
      }
    }

    // Add event listener
    window.addEventListener("mousemove", onMouseMove);
    window.addEventListener("wheel", onWheel);
    window.addEventListener('resize', () => {
      renderer.setSize(window.innerWidth, window.innerHeight);
    });

    const animate = () => {
      const temp = accumulationTarget;
      accumulationTarget = renderTarget;
      renderTarget = temp;
      
      material.uniforms.u_time.value += 0.01;
      material.uniforms.u_seed.value = new THREE.Vector3(Math.random(), Math.random(), Math.random());
      material.uniforms.u_cameraPos.value = rot2(new THREE.Vector3(0,0,0), cameraRadius , mouseX, mouseY);
     
      // mouseX += 0.0003;
      // frameCount = 1;

      let now = performance.now();
      fps[fpsIdx % 20] = (50 /  (now - lastFrameTime));
      fpsIdx += 1;
      fpsDisplay.innerText = `FPS: ${fps.reduce((a,b) => (a + b), 0).toFixed(2)}`;

      material.uniforms.u_buffer.value = accumulationTarget.texture;
      material.uniforms.u_frameCount.value = frameCount++;

      renderer.setRenderTarget(renderTarget);
      renderer.render(scene, camera);
      renderer.setRenderTarget(null);
      renderer.render(scene, camera);
      requestAnimationFrame(animate);
      lastFrameTime = now;
    };
    animate();

    return () => {
      window.removeEventListener("mousemove", onMouseMove);
      window.removeEventListener("wheel", onWheel);
      mountRef.current.removeChild(renderer.domElement);
      renderer.dispose();
      material.dispose();
      accumulationTarget.dispose();
      renderTarget.dispose();
      spaceHDRI.dispose();
    };
  }, []);

  return <div ref={mountRef} />;
};

export default RayTracing;
