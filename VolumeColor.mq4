//+------------------------------------------------------------------+
//|                                  Copyright © 2026, EarnForex.com |
//|                                       https://www.earnforex.com/ |
//+------------------------------------------------------------------+
#property copyright "Copyright © 2026 www.EarnForex.com"
#property link      "https://www.earnforex.com/indicators/Volume-Color/"
#property version   "1.00"
#property strict
#property description "Displays tick volume colored by bar direction, anchored to the bottom of the main chart."

#property indicator_chart_window
#property indicator_buffers 4

// In MQL4 main-chart histograms, buffers are drawn between consecutive
// pairs (0-1, 2-3) and the color of the HIGHER buffer is used. We always
// put the bar's top in the even-indexed buffer so that color shows.
#property indicator_label1  "Volume up top"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrGreen
#property indicator_width1  2

#property indicator_label2  "Volume up bottom"
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrGreen
#property indicator_width2  2

#property indicator_label3  "Volume down top"
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrRed
#property indicator_width3  2

#property indicator_label4  "Volume down bottom"
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrRed
#property indicator_width4  2

input int InpHeightPct = 10; // Bar height (% of visible price range)

double GreenTop[];
double GreenBottom[];
double RedTop[];
double RedBottom[];

int OnInit()
{
    SetIndexBuffer(0, GreenTop);
    SetIndexBuffer(1, GreenBottom);
    SetIndexBuffer(2, RedTop);
    SetIndexBuffer(3, RedBottom);

    // EMPTY_VALUE in either buffer of a pair suppresses that bar.
    SetIndexEmptyValue(0, EMPTY_VALUE);
    SetIndexEmptyValue(1, EMPTY_VALUE);
    SetIndexEmptyValue(2, EMPTY_VALUE);
    SetIndexEmptyValue(3, EMPTY_VALUE);

    IndicatorSetString(INDICATOR_SHORTNAME, "Volume Color");
    
    return INIT_SUCCEEDED;
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double&   open[],
                const double&   high[],
                const double&   low[],
                const double&   close[],
                const long&     tick_volume[],
                const long&     volume[],
                const int&      spread[])
{
    if (Bars(_Symbol, _Period) < rates_total) return -1; // Data readiness check.
    RefreshVisibleBars();
    return rates_total;
}

void OnChartEvent(const int    id,
                  const long&   lparam,
                  const double& dparam,
                  const string& sparam)
{
    if (id == CHARTEVENT_CHART_CHANGE)
    {
        RefreshVisibleBars();
        ChartRedraw(); // Required.
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

    // Use the chart's ACTUAL visible price range so the bars re-anchor
    // when the user changes the vertical scale.
    double price_min = 0.0, price_max = 0.0;
    if (!ChartGetDouble(0, CHART_PRICE_MIN, 0, price_min)) return;
    if (!ChartGetDouble(0, CHART_PRICE_MAX, 0, price_max)) return;
    if (price_max <= price_min) return;

    // MQL4 indicator buffers and the OnCalculate parameter arrays are
    // SERIES-indexed (0 = newest). CHART_FIRST_VISIBLE_BAR is also
    // series-indexed and points at the LEFTMOST (oldest) visible bar.
    int oldest_series = (int)first_bar;
    int newest_series = (int)first_bar - (int)vis_count + 1;
    if (newest_series < 0)         newest_series = 0;
    if (oldest_series > total - 1) oldest_series = total - 1;
    if (newest_series > oldest_series) return;
    int count = oldest_series - newest_series + 1;

    // Copy* fills its result arrays NON-series by default, so arr[0] = oldest
    // of the requested range and arr[count-1] = newest. start_pos = newest
    // series index.
    double open_arr[], close_arr[];
    long   vol_arr[];

    if (CopyOpen      (_Symbol, _Period, newest_series, count, open_arr)  <= 0) return;
    if (CopyClose     (_Symbol, _Period, newest_series, count, close_arr) <= 0) return;
    if (CopyTickVolume(_Symbol, _Period, newest_series, count, vol_arr)   <= 0) return;

    // Normalize against the largest volume currently in view.
    long vol_max = vol_arr[0];
    for (int k = 1; k < count; k++)
        if (vol_arr[k] > vol_max) vol_max = vol_arr[k];
    if (vol_max <= 0) return;

    double pct = InpHeightPct;
    if (pct < 1)   pct = 1;
    if (pct > 100) pct = 100;
    double height = (price_max - price_min) * (pct / 100.0);

    // Walk the copied (non-series) arrays and write back to the
    // (series-indexed) buffers. arr[k] -> series index (oldest_series - k).
    for (int k = 0; k < count; k++)
    {
        int    series_idx = oldest_series - k;
        double scaled_top = price_min + height * ((double)vol_arr[k] / (double)vol_max);
        bool   bullish    = (close_arr[k] > open_arr[k]);
        if (series_idx < 0 || series_idx >= total) return; // Sanity check.
    
        if (bullish)
        {
            GreenTop[series_idx]    = scaled_top;
            GreenBottom[series_idx] = price_min;
            RedTop[series_idx]      = EMPTY_VALUE;
            RedBottom[series_idx]   = EMPTY_VALUE;
        }
        else
        {
            GreenTop[series_idx]    = EMPTY_VALUE;
            GreenBottom[series_idx] = EMPTY_VALUE;
            RedTop[series_idx]      = scaled_top;
            RedBottom[series_idx]   = price_min;
        }
    }
}
//+------------------------------------------------------------------+