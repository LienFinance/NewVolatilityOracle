# Lien Volatility Oracle

## What is Lien Volatility Oracle?
- A simple historical volatility is used in the current ongoing products.
- Simple historical volatility can cause a spike of volatility, which may cause a mispricing.
- The best would be to use an implied volatility oracle for pricing, but as of now there is no reliable external source.
- In this oracle, the contract calculate and register EWMA Volatility based on historical prices at regular interval.

## What is EWMA Volatility?
- See [Explanation](https://www.investopedia.com/articles/07/ewma.asp)
## Volatility Registration
1. Calculate the next timestamp of registration(e.g. in 24 hours).
2. Get price from ChainLink price oracle with the first timestamp after the next regular-interval timestamp(e.g. UTC 0:00).
3. Calculate next EWMA volatility with optimised parameter as following: 

<div align="center">
<img src="./image/tex_volregister.png" height="70">
</div>

4. Register the volatility along with the regular-interval oracle price.

## Current Volatility Calculation
1. Get the latest chainlink price and calculate the relative change ratio to the last regular-interval price.
2. Calculate the volatility in the same manner as the equation above.
3. Return the volatility as MAX(the latest recorded volatility, the volatility).
<div align="center">
<img src="./image/tex_volcurrent.png" height="110">
</div>

## Change Optimised Parameter
- The quants analyst address can change the optimised parameter (lambda) within a certain range when the market condition changes.
1. When labmda is updated, the latest price is recalculated with the new labmda.
2. Recalculation starts from the registered volatility at `latestTimestamp - _dataNum * _interval`.
