## 1.0.1

- refactored calculation of number of bytes to read after a n-channel "get" query.  See `getNumOfExpectedBytes()` for more info. 
- `init()` now uses `tcpip` instead of `visa`
- `enable()` no longer calls query; instead sends command with `fprintf` because no response is expected
- replaced `contains()` with `isempty(strfind())` to support MATLAB versions < 2016b.
## 1.0.0

- First production commit