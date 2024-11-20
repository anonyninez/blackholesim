import React from 'react';
import BlackHoleEffect from './RayTracing.js';
import './App.css';
const App = () => {
  return (
    <div style={{backgroundColor:'black',  width: "100vw", sheight:'100vh'}}>
      <BlackHoleEffect />
    </div>
  );
};

export default App;
