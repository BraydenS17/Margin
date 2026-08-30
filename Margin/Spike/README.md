# Spike

Throwaway prototypes — **not part of the shipped app** (debug builds only).

- `PDFInkSpikeView.swift` — the original ink-over-zoomed-PDF risk spike
  (`PDFPageOverlayViewProvider` + per-page `PKCanvasView`). The shipped PDF
  import (M4) rasterizes PDF pages as static backgrounds instead, so this is
  kept only as reference for a future zoomable PDF viewer.
