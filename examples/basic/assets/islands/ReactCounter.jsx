import React, { useState } from "react";

export default function ReactCounter({ initial = 0 }) {
  const [count, setCount] = useState(initial);

  return (
    <button
      className="button island-button"
      type="button"
      onClick={() => setCount((value) => value + 1)}
    >
      React clicks: {count}
    </button>
  );
}
