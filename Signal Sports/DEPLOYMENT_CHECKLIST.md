# Smart Injury Adjustments - Deployment Checklist

## ✅ Pre-Deployment Verification

### Core Modules Tested
- [x] `src/core/player_importance.py` - Working ✅
- [x] `src/core/config.py` - Working ✅
- [x] `src/core/injury_cache.py` - Working ✅
- [x] `src/core/injury_client.py` - Enhanced ✅
- [x] `src/core/feature_builder.py` - Enhanced ✅

### Integration Points
- [x] API Service (`src/api/dependencies.py`) - Wired ✅
- [x] Daily Predictions (`src/daily_predictions.py`) - Updated ✅
- [x] Core Exports (`src/core/__init__.py`) - Updated ✅

### Documentation
- [x] User Guide (`docs/INJURY_ADJUSTMENTS.md`) - Complete ✅
- [x] Implementation Summary (`IMPLEMENTATION_SUMMARY.md`) - Complete ✅
- [x] Test Suite (`test/test_injury_adjustments.py`) - Complete ✅

### No Linter Errors
- [x] All new files pass linting ✅

---

## 🚀 Deployment Steps

### Step 1: Environment Configuration (Optional)

Set environment variables if you want to override defaults:

```bash
# Enable/disable adjustments
export INJURY_ADJUSTMENTS_ENABLED=true

# Tuning parameters
export INJURY_ADJUSTMENT_MULTIPLIER=20
export INJURY_MAX_ADJUSTMENT=-100

# Cache settings
export INJURY_CACHE_TTL=14400

# Logging
export LOG_INJURY_ADJUSTMENTS=true
export DEBUG_INJURY_CALCULATIONS=false
```

### Step 2: Test Locally

```bash
# Test individual modules
python src/core/player_importance.py
python src/core/config.py
python src/core/injury_cache.py

# Run test suite
python test/test_injury_adjustments.py

# Test daily predictions
python src/daily_predictions.py --date 2026-02-10
```

### Step 3: Deploy to Production

The changes are **backward compatible** - no migration needed:

1. **Push code to repository**
   ```bash
   git add .
   git commit -m "Add smart injury-based Elo adjustments"
   git push
   ```

2. **Restart API service**
   - Injury adjustments will be enabled automatically
   - No configuration changes required

3. **Verify API is working**
   ```bash
   curl http://your-api/health
   curl http://your-api/api/v1/predict/today
   ```

### Step 4: Monitor

Watch for:
1. **API logs** - Look for injury adjustment messages
2. **Cache hit rates** - Check cache statistics
3. **Prediction accuracy** - Compare with historical baseline
4. **Error rates** - Verify no increase in errors

---

## 📊 Monitoring Commands

### Check Configuration
```bash
python -c "from src.core.config import print_config; print_config()"
```

### Check Cache Statistics
```python
from src.core.injury_cache import get_global_cache
cache = get_global_cache()
print(cache.get_stats())
```

### Test Injury Fetching
```python
from src.core.injury_client import InjuryClient
from src.core.team_mapper import TeamMapper

client = InjuryClient(TeamMapper())
reports = client.get_all_injuries()
print(f"Found {len(reports)} teams with injuries")
```

### Check Specific Team
```python
lakers = client.get_team_injuries(1610612747)
if lakers:
    from src.core.injury_client import calculate_injury_adjustment
    adj = calculate_injury_adjustment(lakers, debug=True)
    print(f"Lakers adjustment: {adj} Elo")
```

---

## 🔍 Post-Deployment Verification

### Week 1: Stability Check
- [ ] No API errors related to injury adjustments
- [ ] Cache is functioning properly
- [ ] ESPN API calls are successful
- [ ] Logs show adjustments being applied

### Week 2-4: Accuracy Measurement
- [ ] Track predictions vs actuals
- [ ] Calculate accuracy improvement
- [ ] Identify games where adjustments helped most
- [ ] Look for false positives

### Month 2: Fine-Tuning
- [ ] Review adjustment magnitudes
- [ ] Update player importance list
- [ ] Adjust multipliers if needed
- [ ] Consider adding more granular tiers

---

## 🎯 Success Criteria

### Technical Success
- [x] All modules working without errors
- [x] Backward compatibility maintained
- [x] No performance degradation
- [x] Graceful error handling

### Business Success
- [ ] Overall accuracy improves by 0.5-1.5%
- [ ] Games with major injuries improve by 2-5%
- [ ] No false positives harming accuracy
- [ ] User feedback is positive

---

## 🛠️ Troubleshooting

### If adjustments aren't working:

1. **Check if enabled:**
   ```python
   from src.core.config import INJURY_ADJUSTMENTS_ENABLED
   print(INJURY_ADJUSTMENTS_ENABLED)
   ```

2. **Check injury client:**
   ```python
   from src.core.injury_client import InjuryClient
   client = InjuryClient()
   reports = client.get_all_injuries()
   print(len(reports))
   ```

3. **Check feature builder:**
   ```python
   # Verify injury_client is passed to FeatureBuilder
   print(feature_builder.injury_client)
   print(feature_builder._injury_adjustments_enabled)
   ```

### If ESPN API is failing:

- Cache will provide fallback with stale data
- Check `INJURY_USE_STALE_CACHE=true` is set
- Increase `INJURY_CACHE_TTL` to reduce API calls

### If adjustments are too aggressive:

```python
# Reduce multiplier
export INJURY_ADJUSTMENT_MULTIPLIER=15

# Reduce max penalty
export INJURY_MAX_ADJUSTMENT=-75
```

---

## 📝 Rollback Plan

If issues arise, you can disable injury adjustments without code changes:

```bash
# Disable via environment variable
export INJURY_ADJUSTMENTS_ENABLED=false

# Restart API
```

Or use CLI flag:
```bash
python src/daily_predictions.py --no-injury-adjustments
```

---

## 🎉 Deployment Complete!

**All systems ready for production deployment.**

- ✅ 9/9 todos completed
- ✅ All modules tested and working
- ✅ Documentation complete
- ✅ Backward compatible
- ✅ Error handling robust
- ✅ Configuration flexible

**Next:** Deploy, monitor, and measure impact over 2-4 weeks.

---

**Questions?** See `docs/INJURY_ADJUSTMENTS.md` for detailed documentation.
