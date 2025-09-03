# Character-Based Finalization Feature

## Overview

This feature prevents large run-on paragraphs in user captions by automatically finalizing interim text when it exceeds a configurable character limit. The system uses **smart finalization** that looks for natural break points rather than simply cutting at the character limit. This is particularly useful when speakers don't leave natural pauses between sentences.

## Implementation Details

### Backend Changes

1. **New User Setting**: Added `user_max_chars_before_finalize` to the default user settings (default: 400 characters)

2. **Modified `process_user_speech_text` function** in both `captionStable.py` and `captionStable_docker.py`:
   - Added character limit checking for interim text
   - When interim text exceeds the limit, it's automatically finalized and moved to history
   - This prevents extremely long run-on paragraphs

3. **Smart Finalization Logic**:
   ```python
   # Check if the current interim text exceeds the character limit
   if len(corrected_text) >= user_max_chars:
       log_message(logging.INFO, f"Interim text for {lang} exceeded {user_max_chars} characters ({len(corrected_text)}), looking for smart break point")
       
       # Try to find a smart break point
       final_text, remaining_text = find_smart_break_point(corrected_text, user_max_chars)
       
       if final_text.strip() != "":
           # Add finalized text to history
           user_caption_history[lang].append(final_text)
           # Set remaining text as new interim text
           user_last_text[lang] = remaining_text
   ```

4. **Smart Break Point Detection**:
   The system prioritizes break points in this order:
   - **Sentence endings** (highest priority): `.`, `!`, `?`, `。`, `！`, `？`
   - **Clause boundaries** (medium priority): `,`, `;`, `:`, `，`, `；`, `：`
   - **Word boundaries** (lower priority): spaces, tabs, newlines
   - **Fallback**: If no good break point is found, breaks at the last word boundary before the limit

### Frontend Changes

1. **Settings UI**: Added a new input field in the user settings menu:
   - Label: "Max Characters Before Finalize"
   - Default value: 400
   - Range: 100-1000 characters
   - Real-time updates when changed

2. **JavaScript Integration**:
   - Settings are saved to localStorage and sent to backend
   - Backend settings are loaded on page load
   - Changes are applied immediately

## Configuration

### Default Settings
- **Default character limit**: 400 characters
- **Configurable range**: 100-1000 characters
- **Setting name**: `user_max_chars_before_finalize`

### How to Configure
1. Open the user view (`/user`)
2. Click the "Settings" button
3. Adjust the "Max Characters Before Finalize" value
4. Changes are applied immediately

## Benefits

1. **Improved Readability**: Prevents extremely long paragraphs that are difficult to read
2. **Smart Breaking**: Finds natural break points instead of cutting mid-sentence
3. **Better User Experience**: Maintains manageable caption lengths with logical breaks
4. **Configurable**: Users can adjust the limit based on their preferences
5. **Automatic**: No manual intervention required
6. **Language Agnostic**: Works for all supported languages including non-Latin scripts
7. **Translation Friendly**: Handles punctuation from multiple languages (English, Spanish, Japanese, etc.)

## Technical Notes

- The feature only affects interim (non-finalized) text
- Finalized text is not affected by this limit
- The limit is applied per language independently
- Logging is added to track when finalization occurs
- The feature is backward compatible (defaults to 400 if not set)

## Testing

The implementation has been tested with:
- Short text (under limit): No finalization
- Long text (over limit): Automatic finalization
- Boundary cases (exactly at limit): Proper finalization
- Multiple languages: Works independently for each language

## Files Modified

1. `captionStable.py` - Main implementation
2. `captionStable_docker.py` - Docker version implementation  
3. `user.html` - Frontend UI and JavaScript
4. `user_settings.json` - Will be updated when users change settings

## Usage Examples

### Example 1: Sentence with Natural Ending
**Input**: "This is a very long sentence that goes on and on without any natural breaks until we reach a point where we need to finalize the caption. This sentence ends with a period. This next sentence should be in the next caption."

**Result**: 
- **Caption 1**: "This is a very long sentence that goes on and on without any natural breaks until we reach a point where we need to finalize the caption. This sentence ends with a period."
- **Caption 2**: "This next sentence should be in the next caption."

### Example 2: Long Sentence with Comma
**Input**: "This is a very long sentence that contains multiple clauses, and it should break at the comma rather than in the middle of a word, which would make more sense for readability."

**Result**:
- **Caption 1**: "This is a very long sentence that contains multiple clauses,"
- **Caption 2**: "and it should break at the comma rather than in the middle of a word, which would make more sense for readability."

### Example 3: No Natural Breaks
**Input**: "This is an extremely long sentence that has no natural break points whatsoever and will need to be broken at a word boundary to prevent it from becoming unreadable."

**Result**:
- **Caption 1**: "This is an extremely long sentence that has no natural break points whatsoever and will need to be broken at a word boundary to prevent it from becoming"
- **Caption 2**: "unreadable."

This results in more readable, manageable paragraphs with logical breaks for the audience. 