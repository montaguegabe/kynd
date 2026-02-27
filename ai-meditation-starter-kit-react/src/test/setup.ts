import "@testing-library/jest-dom/vitest";

HTMLCanvasElement.prototype.getContext = () => ({}) as never;
