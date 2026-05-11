//+------------------------------------------------------------------+
//|                                  Copyright © 2026, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2026 www.EarnForex.com"
#property link      "https://www.earnforex.com/indicators/Volume-Color/"
#property version   "1.00"

#property description "Displays volume colored by bar direction, anchored to the bottom of the main chart."

#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   1

#property indicator_label1  "Volume"
#property indicator_type1   DRAW_COLOR_HISTOGRAM2
#property indicator_color1  clrGreen, clrRed
#property indicator_width1  2

input ENUM_APPLIED_VOLUME InpVolumeType = VOLUME_TICK; // Volume type
input int                 InpHeightPct  = 10;          // Bar height (% of visible price range)

// Buffers for DRAW_COLOR_HISTOGRAM2: bottom, top, color index.
double BarBottom[];
double BarTop[];
double BarColor[];

// Color indices match the order of clrGreen, clrRed in indicator_color1.
#define COLOR_GREEN 0
#define COLOR_RED   1

int OnInit()
{
    SetIndexBuffer(0, BarBottom, INDICATOR_DATA);
    SetIndexBuffer(1, BarTop,    INDICATOR_DATA);
    SetIndexBuffer(2, BarColor,  INDICATOR_COLOR_INDEX);

    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);

    string short_name = "Volume Color (" + ((InpVolumeType == VOLUME_TICK) ? "Tick" : "Real") + ")";
    IndicatorSetString(INDICATOR_SHORTNAME, short_name);

    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double   &open[],
                const double   &high[],
                const double   &low[],
                const double   &close[],
                const long     &tick_volume[],
                const long     &volume[],
                const int      &spread[])
{
    if (rates_total <= 0) return 0;

    if (prev_calculated == 0)
    {
        ArrayInitialize(BarBottom, EMPTY_VALUE);
        ArrayInitialize(BarTop,    EMPTY_VALUE);
    }

    RefreshVisibleBars();
    return rates_total;
}

void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if (id == CHARTEVENT_CHART_CHANGE)
    {
        RefreshVisibleBars();
        ChartRedraw();
    }
}

//+------------------------------------------------------------------+
//| Compute scaled bar geometry for the currently visible bars.      |
//+------------------------------------------------------------------+
void RefreshVisibleBars()
{
    int total = Bars(_Symbol, _Period);
    if (total <= 0) return;

    long first_bar = ChartGetInteger(0, CHART_FIRST_VISIBLE_BAR);
    long vis_count = ChartGetInteger(0, CHART_VISIBLE_BARS);
    if (first_bar < 0 || vis_count <= 0) return;

    // Use the chart's ACTUAL visible price range (chart min/max).
    // This is what makes the bars re-anchor when the user changes the vertical scale.
    double price_min = 0.0, price_max = 0.0;
    if (!ChartGetDouble(0, CHART_PRICE_MIN, 0, price_min)) return;
    if (!ChartGetDouble(0, CHART_PRICE_MAX, 0, price_max)) return;
    if (price_max <= price_min) return;

    // Translate the visible range into our buffers' non-series indexing (where 0 = oldest bar) and clamp to actual data bounds.
    int start_ns   = total - 1 - (int)first_bar;
    int end_ns     = start_ns + (int)vis_count - 1;
    int calc_start = (start_ns < 0)         ? 0           : start_ns;
    int calc_end   = (end_ns   > total - 1) ? total - 1   : end_ns;
    int calc_count = calc_end - calc_start + 1;
    if (calc_count <= 0) return;

    // Series start_pos for Copy* = the NEWEST bar in our calc range.
    int copy_start = total - 1 - calc_end;

    double open_arr[], close_arr[];
    long   vol_arr[];

    if (CopyOpen (_Symbol, _Period, copy_start, calc_count, open_arr)  <= 0) return;
    if (CopyClose(_Symbol, _Period, copy_start, calc_count, close_arr) <= 0) return;

    int copied = (InpVolumeType == VOLUME_TICK)
                 ? CopyTickVolume(_Symbol, _Period, copy_start, calc_count, vol_arr)
                 : CopyRealVolume(_Symbol, _Period, copy_start, calc_count, vol_arr);
    if (copied <= 0) return;

    // Normalize against the largest volume currently in view.
    long vol_max = vol_arr[0];
    for (int k = 1; k < calc_count; k++)
        if (vol_arr[k] > vol_max) vol_max = vol_arr[k];
    if (vol_max <= 0) return;

    double pct = InpHeightPct;
    if (pct < 1)   pct = 1;
    if (pct > 100) pct = 100;
    double height = (price_max - price_min) * (pct / 100.0);

    for (int k = 0; k < calc_count; k++)
    {
        int    idx        = calc_start + k;
        double scaled_top = price_min + height * ((double)vol_arr[k] / (double)vol_max);

        BarBottom[idx] = price_min;
        BarTop[idx]    = scaled_top;
        BarColor[idx]  = (close_arr[k] > open_arr[k]) ? COLOR_GREEN : COLOR_RED;
    }
}
//+------------------------------------------------------------------+