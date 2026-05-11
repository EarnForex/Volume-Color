// -------------------------------------------------------------------------------
//   Displays tick volume colored by bar direction, anchored to the bottom of the
//   main chart. Each visible bar is rendered as a vertical chart trend line
//   running from the chart's bottom edge up to a height proportional to its
//   share of the largest volume currently in view.
//
//   Version 1.00
//   Copyright 2026, EarnForex.com
//   https://www.earnforex.com/indicators/Volume-Color/
// -------------------------------------------------------------------------------

using System.Collections.Generic;
using cAlgo.API;

namespace cAlgo
{
    [Indicator(IsOverlay = true, AccessRights = AccessRights.None)]
    public class VolumeColor : Indicator
    {
        [Parameter("Bar height (% of visible price range)", DefaultValue = 10, MinValue = 1, MaxValue = 100)]
        public double HeightPct { get; set; }

        [Parameter("Up color", DefaultValue = "Green")]
        public Color UpColor { get; set; }

        [Parameter("Down color", DefaultValue = "Red")]
        public Color DownColor { get; set; }

        [Parameter("Thickness", DefaultValue = 2, MinValue = 1, MaxValue = 10)]
        public int Thickness { get; set; }

        private const string ObjectPrefix = "VolColor_";
        private readonly HashSet<int> _drawnIndices = new HashSet<int>();

        protected override void Initialize()
        {
            // ScrollChanged fires when the first visible bar index OR the top/
            // bottom Y of the chart changes, i.e. on horizontal scroll, zoom,
            // vertical scale changes, and resize. This is the cTrader
            // equivalent of MT4's CHARTEVENT_CHART_CHANGE for our purposes.
            Chart.ScrollChanged += OnScrollChanged;
        }

        public override void Calculate(int index)
        {
            // During the initial historical load Calculate is called for every
            // bar, so refresh only when we hit the latest one. After init,
            // each tick fires Calculate at index = Bars.Count - 1 again, which
            // keeps the current bar's volume up to date in real time.
            if (index == Bars.Count - 1)
                RefreshVisibleBars();
        }

        private void OnScrollChanged(ChartScrollEventArgs args)
        {
            RefreshVisibleBars();
        }

        private void RefreshVisibleBars()
        {
            // Clamp the visible bar range to actual data — the chart's right
            // edge can extend past the latest bar when offset is enabled.
            int first = Chart.FirstVisibleBarIndex;
            int last  = Chart.LastVisibleBarIndex;
            if (first < 0)          first = 0;
            if (last >= Bars.Count) last  = Bars.Count - 1;
            if (first > last) return;

            // Use the chart's ACTUAL visible price range (TopY/BottomY) rather
            // than scanning bar highs/lows. This is what makes the bars
            // re-anchor when the user changes the vertical scale.
            double priceMin = Chart.BottomY;
            double priceMax = Chart.TopY;
            if (priceMax <= priceMin) return;

            // Normalize against the largest volume currently in view.
            double volMax = 0;
            for (int i = first; i <= last; i++)
            {
                double v = Bars.TickVolumes[i];
                if (v > volMax) volMax = v;
            }
            if (volMax <= 0) return;

            double height = (priceMax - priceMin) * (HeightPct / 100.0);

            // Draw / update one vertical trend line per visible bar. Reusing
            // the same object name updates the existing line in place.
            var stillVisible = new HashSet<int>();
            for (int i = first; i <= last; i++)
            {
                double v         = Bars.TickVolumes[i];
                double scaledTop = priceMin + height * (v / volMax);
                bool   bullish   = Bars.ClosePrices[i] > Bars.OpenPrices[i];
                Color  c         = bullish ? UpColor : DownColor;

                string name = ObjectPrefix + i;
                var line = Chart.DrawTrendLine(name, i, priceMin, i, scaledTop, c);
                line.Thickness     = Thickness;
                line.IsInteractive = false;
                line.IsLocked      = true;

                stillVisible.Add(i);
            }

            // Remove objects for bars that have scrolled out of view so they
            // don't accumulate as the user moves around the chart.
            foreach (int idx in _drawnIndices)
            {
                if (!stillVisible.Contains(idx))
                    Chart.RemoveObject(ObjectPrefix + idx);
            }

            _drawnIndices.Clear();
            foreach (int idx in stillVisible)
                _drawnIndices.Add(idx);
        }
    }
}