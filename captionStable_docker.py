import azure.cognitiveservices.speech as speechsdk
import logging
import os
import asyncio
import threading
import socket
from fastapi import FastAPI, Depends, HTTPException, WebSocket, Query
from fastapi.responses import HTMLResponse, Response
from fastapi.security import HTTPBasic, HTTPBasicCredentials
import uvicorn
import time
import atexit
from threading import Timer
import unittest
import schedule
import json
from datetime import datetime, date
import re
import textwrap
from dotenv import load_dotenv
import webbrowser
from typing import Dict, List

# Try to import sounddevice, but don't fail if it's not available
try:
    import sounddevice as sd
    SOUNDDEVICE_AVAILABLE = True
    print("sounddevice module loaded successfully")
except Exception:
    sd = None
    SOUNDDEVICE_AVAILABLE = False
    print("Warning: sounddevice not available (PortAudio initialization failed)")
    print("Audio device enumeration will be disabled, but speech recognition should still work")

# Load environment variables from .env file
load_dotenv()

# -------------------------------------------------------------------
# Setup logging
# -------------------------------------------------------------------
CURRENT_DIR = os.path.dirname(os.path.abspath(__file__))
LOG_FILE = os.path.join(CURRENT_DIR, "caption_log.txt")

logging.basicConfig(
    filename=LOG_FILE,
    level=logging.DEBUG,
    format='%(asctime)s [%(levelname)s] [SpeechCaption] %(message)s',
    datefmt='%Y-%m-%d %H:%M:%S'
)

def log_message(level, message):
    logging.log(level, f"[SpeechCaption] {message}")

# -------------------------------------------------------------------
# Configuration
# -------------------------------------------------------------------
CONFIG_FILE = os.path.join(CURRENT_DIR, "config.json")

def load_config():
    try:
        with open(CONFIG_FILE, 'r') as f:
            config = json.load(f)
        # Override speech_key with environment variable if set
        config["speech_key"] = os.getenv("AZURE_SPEECH_KEY", config.get("speech_key", ""))
        log_message(logging.INFO, "Configuration loaded successfully")
        return config
    except FileNotFoundError:
        log_message(logging.ERROR, f"Config file not found at {CONFIG_FILE}")
        raise FileNotFoundError(f"Config file not found: {CONFIG_FILE}")
    except json.JSONDecodeError as e:
        log_message(logging.ERROR, f"Failed to parse config JSON: {e}")
        raise ValueError(f"Invalid JSON in config file: {e}")
    except Exception as e:
        log_message(logging.ERROR, f"Failed to load config: {e}")
        raise

CONFIG = load_config()

# Validate Azure key
if not CONFIG["speech_key"]:
    raise ValueError("AZURE_SPEECH_KEY environment variable or config.speech_key not set")

# -------------------------------------------------------------------
# File Paths
# -------------------------------------------------------------------
SCHEDULE_FILE = os.path.join(CURRENT_DIR, "schedule.json")
DICTIONARY_FILE = os.path.join(CURRENT_DIR, "dictionary.json")
USER_SETTINGS_FILE = os.path.join(CURRENT_DIR, "user_settings.json")

# Timed finalization constants
MAX_FINALIZE_SECONDS = 2.0  # Force finalization after 2 seconds of no final result

# Default user settings
DEFAULT_USER_SETTINGS = {
    "user_bg_color": "#000000",
    "user_text_color": "#FFFFFF",
    "user_font_style": "Arial",
    "user_font_size": 24,
    "user_max_line_length": 500,
    "user_lines": 3
}

# -------------------------------------------------------------------
# User Settings Persistence
# -------------------------------------------------------------------
def load_user_settings():
    try:
        if not os.path.exists(USER_SETTINGS_FILE):
            log_message(logging.WARNING, f"User settings file not found at {USER_SETTINGS_FILE}")
            return DEFAULT_USER_SETTINGS.copy()
        with open(USER_SETTINGS_FILE, 'r') as f:
            data = json.load(f)
            log_message(logging.INFO, "User settings loaded successfully")
            return data
    except json.JSONDecodeError as e:
        log_message(logging.ERROR, f"Failed to parse user settings JSON: {e}")
        return DEFAULT_USER_SETTINGS.copy()
    except Exception as e:
        log_message(logging.ERROR, f"Failed to load user settings: {e}")
        return DEFAULT_USER_SETTINGS.copy()

def save_user_settings(settings):
    try:
        with open(USER_SETTINGS_FILE, 'w') as f:
            json.dump(settings, f, indent=2)
        log_message(logging.INFO, "User settings saved")
    except Exception as e:
        log_message(logging.ERROR, f"Failed to save user settings: {e}")

# Load initial user settings
USER_SETTINGS = load_user_settings()

# -------------------------------------------------------------------
# Load HTML templates at startup
# -------------------------------------------------------------------
def load_html_template(filename):
    try:
        with open(os.path.join(CURRENT_DIR, filename), 'r') as f:
            template = f.read()
        log_message(logging.INFO, f"Loaded HTML template: {filename}")
        return template
    except Exception as e:
        log_message(logging.ERROR, f"Failed to load HTML template {filename}: {e}")
        raise

ROOT_TEMPLATE = load_html_template("root.html")
USER_TEMPLATE = load_html_template("user.html")
SETUP_TEMPLATE = load_html_template("setup.html")
DICTIONARY_PAGE_TEMPLATE = load_html_template("dictionary_page.html")
DASHBOARD_TEMPLATE = load_html_template("dashboard.html")

# -------------------------------------------------------------------
# Dictionary Persistence
# -------------------------------------------------------------------
def load_dictionary():
    try:
        if not os.path.exists(DICTIONARY_FILE):
            log_message(logging.WARNING, f"Dictionary file not found at {DICTIONARY_FILE}")
            return {"bible_books": [], "spelling_corrections": {}, "custom_phrases": [], "supported_languages": []}
        with open(DICTIONARY_FILE, 'r') as f:
            data = json.load(f)
            log_message(logging.INFO, "Dictionary loaded successfully")
            return data
    except json.JSONDecodeError as e:
        log_message(logging.ERROR, f"Failed to parse dictionary JSON: {e}")
        return {"bible_books": [], "spelling_corrections": {}, "custom_phrases": [], "supported_languages": []}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to load dictionary: {e}")
        return {"bible_books": [], "spelling_corrections": {}, "custom_phrases": [], "supported_languages": []}

def save_dictionary(dictionary):
    try:
        with open(DICTIONARY_FILE, 'w') as f:
            json.dump(dictionary, f, indent=2)
        log_message(logging.INFO, "Dictionary saved")
    except Exception as e:
        log_message(logging.ERROR, f"Failed to save dictionary: {e}")

# -------------------------------------------------------------------
# Schedule Persistence
# -------------------------------------------------------------------
def load_schedule():
    try:
        if os.path.exists(SCHEDULE_FILE):
            with open(SCHEDULE_FILE, 'r') as f:
                data = json.load(f)
                if isinstance(data, list):
                    migrated_schedules = []
                    today = datetime.now().date()
                    for s in data:
                        if 'recurrence_type' not in s:
                            s['recurrence_type'] = 'yearly' if s.get('is_recurring', False) else 'one-time'
                            s.pop('is_recurring', None)
                        
                        # Handle different recurrence types
                        schedule_date = datetime.strptime(s['date'], '%Y-%m-%d').date()
                        if s['recurrence_type'] == 'one-time':
                            # Skip if the event is in the past
                            if schedule_date < today:
                                continue
                        elif s['recurrence_type'] == 'weekly':
                            # Keep if it's a weekly event (regardless of date)
                            pass
                        elif s['recurrence_type'] == 'monthly':
                            # Keep if it's a monthly event (regardless of date)
                            pass
                        elif s['recurrence_type'] == 'yearly':
                            # Keep if it's a yearly event (regardless of date)
                            pass
                        
                        migrated_schedules.append(s)
                    
                    # Save the cleaned schedule if any past events were removed
                    if len(migrated_schedules) < len(data):
                        save_schedule(migrated_schedules)
                    
                    return migrated_schedules
                else:
                    return []
        else:
            return []
    except Exception as e:
        log_message(logging.ERROR, f"Failed to load schedule: {e}")
        return []

def save_schedule(schedules):
    try:
        with open(SCHEDULE_FILE, 'w') as f:
            json.dump(schedules, f, indent=2)
        log_message(logging.INFO, "Schedule saved")
    except Exception as e:
        log_message(logging.ERROR, f"Failed to save schedule: {e}")

# -------------------------------------------------------------------
# FastAPI Setup
# -------------------------------------------------------------------
app = FastAPI()
security = HTTPBasic()

def get_current_username(credentials: HTTPBasicCredentials = Depends(security)):
    correct_username = os.getenv("ADMIN_USERNAME", "admin")
    correct_password = os.getenv("ADMIN_PASSWORD", "Northway12121")
    log_message(logging.DEBUG, f"Auth attempt: provided username={credentials.username}")
    if not (credentials.username == correct_username and credentials.password == correct_password):
        log_message(logging.WARNING, f"Authentication failed for user: {credentials.username}")
        raise HTTPException(status_code=401, detail="Invalid credentials")
    return credentials.username

def get_local_ip():
    try:
        # Connect to a remote address to determine local IP
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        local_ip = s.getsockname()[0]
        s.close()
        return local_ip
    except Exception:
        return "127.0.0.1"

# -------------------------------------------------------------------
# Speech Recognition Setup (Docker-optimized)
# -------------------------------------------------------------------
# Initialize speech config but not recognizers immediately
speech_config = speechsdk.SpeechConfig(
    subscription=CONFIG["speech_key"],
    region=CONFIG["service_region"]
)
speech_config.speech_recognition_language = "en-US"
speech_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_InitialSilenceTimeoutMs, CONFIG["initial_silence_timeout_ms"])
speech_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, CONFIG["end_silence_timeout_ms"])

# Initialize recognizers as None - they will be created when needed
production_recognizer = None
user_recognizer = None
translation_recognizer = None

def initialize_recognizers():
    """Initialize speech recognizers only when needed"""
    global production_recognizer, user_recognizer, translation_recognizer
    
    try:
        log_message(logging.INFO, "Initializing speech recognizers...")
        log_message(logging.INFO, f"Azure Speech Key exists: {'AZURE_SPEECH_KEY' in os.environ}")
        log_message(logging.INFO, f"Azure Speech Region: {CONFIG.get('service_region', 'Not set')}")
        
        # Try to configure audio settings for Docker environment
        try:
            # Set audio configuration for Docker
            speech_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, "1000")
            speech_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_InitialSilenceTimeoutMs, "1000")
            log_message(logging.INFO, "Speech config properties set")
            
            # Try explicit ALSA device specification for Docker
            audio_config_production = None
            audio_config_user = None
            audio_config_translation = None
            
            try:
                # Try using default audio configuration first (most compatible with Docker)
                log_message(logging.INFO, "Attempting default audio configuration")
                audio_config_production = None
                audio_config_user = None
                audio_config_translation = None
                log_message(logging.INFO, "Using default audio configuration for Docker compatibility")
            except Exception as default_error:
                log_message(logging.WARNING, f"Default audio config failed: {default_error}")
                try:
                    # Fallback to explicit ALSA device path
                    log_message(logging.INFO, "Attempting explicit ALSA device configuration")
                    audio_config_production = speechsdk.audio.AudioConfig(device_name="hw:1,0")
                    audio_config_user = speechsdk.audio.AudioConfig(device_name="hw:1,0") 
                    audio_config_translation = speechsdk.audio.AudioConfig(device_name="hw:1,0")
                    log_message(logging.INFO, "Created ALSA device configurations: hw:1,0")
                except Exception as alsa_error:
                    log_message(logging.WARNING, f"ALSA device config failed: {alsa_error}")
                    try:
                        # Final fallback to plughw which provides automatic format conversion
                        log_message(logging.INFO, "Trying plughw device configuration")
                        audio_config_production = speechsdk.audio.AudioConfig(device_name="plughw:1,0")
                        audio_config_user = speechsdk.audio.AudioConfig(device_name="plughw:1,0")
                        audio_config_translation = speechsdk.audio.AudioConfig(device_name="plughw:1,0")
                        log_message(logging.INFO, "Created plughw device configurations")
                    except Exception as plughw_error:
                        log_message(logging.WARNING, f"plughw device config failed: {plughw_error}")
                        # Final fallback to None (default)
                        audio_config_production = None
                        audio_config_user = None
                        audio_config_translation = None
                        log_message(logging.INFO, "Using default audio configuration as final fallback")
            
            log_message(logging.INFO, "Audio configuration set for Docker environment")
        except Exception as audio_config_error:
            log_message(logging.WARNING, f"Could not set audio configuration: {audio_config_error}")
            audio_config_production = None
            audio_config_user = None
            audio_config_translation = None
        
        # Production recognizer is not created to avoid audio conflicts
        # User recognizer will handle both user and production views
        production_recognizer = None
        log_message(logging.INFO, "Production recognizer not created - user recognizer will handle both views")
        
        # User recognizer for user view (English)
        try:
            if audio_config_user:
                user_recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config, audio_config=audio_config_user)
                log_message(logging.INFO, "User recognizer created with custom audio config")
            else:
                user_recognizer = speechsdk.SpeechRecognizer(speech_config=speech_config)
                log_message(logging.INFO, "User recognizer created with default audio config")
        except Exception as user_error:
            log_message(logging.ERROR, f"Failed to create user recognizer: {user_error}")
            user_recognizer = None
        
        # Translation recognizer
        try:
            translation_config = speechsdk.translation.SpeechTranslationConfig(
                subscription=CONFIG["speech_key"],
                region=CONFIG["service_region"],
                speech_recognition_language="en-US"
            )
            dictionary = load_dictionary()
            for lang in dictionary.get("supported_languages", []):
                if lang["code"] != "en-US":
                    translation_config.add_target_language(lang["code"])
            translation_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_InitialSilenceTimeoutMs, CONFIG["initial_silence_timeout_ms"])
            translation_config.set_property(speechsdk.PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, CONFIG["end_silence_timeout_ms"])
            
            if audio_config_translation:
                translation_recognizer = speechsdk.translation.TranslationRecognizer(translation_config=translation_config, audio_config=audio_config_translation)
                log_message(logging.INFO, "Translation recognizer created with custom audio config")
            else:
                translation_recognizer = speechsdk.translation.TranslationRecognizer(translation_config=translation_config)
                log_message(logging.INFO, "Translation recognizer created with default audio config")
        except Exception as trans_error:
            log_message(logging.ERROR, f"Failed to create translation recognizer: {trans_error}")
            translation_recognizer = None
        
        log_message(logging.INFO, f"Speech recognizers initialized successfully - Production: {production_recognizer is not None}, User: {user_recognizer is not None}, Translation: {translation_recognizer is not None}")
        return True
    except Exception as e:
        log_message(logging.ERROR, f"Failed to initialize speech recognizers: {e}")
        # Return True anyway to allow the application to continue without audio
        log_message(logging.INFO, "Continuing without speech recognition - audio features will be disabled")
        return True

# -------------------------------------------------------------------
# Global Variables
# -------------------------------------------------------------------
is_recognizing = False
should_be_recognizing = False

# User view caption state (separate from production view)
user_caption = ""
user_caption_update_pending = False
user_caption_history = {}  # Dictionary to store history for each language
user_last_text = {}  # Dictionary to store interim text for each language
current_user_language = "en-US"  # Track currently selected language in user view

# Initialize history for all supported languages
dictionary = load_dictionary()
for lang in dictionary.get("supported_languages", []):
    user_caption_history[lang["code"]] = []
    user_last_text[lang["code"]] = ""
clients = []

# -------------------------------------------------------------------
# Text Processing
# -------------------------------------------------------------------
transcript = []
last_caption = ""

# Production view caption state (separate from user view)
production_caption_update_pending_english = False
production_caption_update_pending_translations = False
production_caption_update_translations = {"en-US": ""}
production_caption = ""
production_caption_history = ""  # Store the accumulated production caption text

# User view caption state (completely separate)
user_caption = ""
user_caption_update_pending = False
user_caption_history = {}  # Dictionary to store history for each language
user_last_text = {}  # Dictionary to store interim text for each language
current_user_language = "en-US"  # Track currently selected language in user view

# Initialize history for all supported languages
dictionary = load_dictionary()
for lang in dictionary.get("supported_languages", []):
    user_caption_history[lang["code"]] = []
    user_last_text[lang["code"]] = ""

dictionary = load_dictionary()
bible_books = dictionary["bible_books"]
spelling_corrections_dict = dictionary["spelling_corrections"]
custom_phrases = dictionary["custom_phrases"]

# Timed finalization tracking
last_partial_time = time.time()
finalization_timer = None

def spelling_corrections(text):
    words = text.split()
    return " ".join([spelling_corrections_dict.get(word.lower(), word) for word in words])

def correct_bible_books(text):
    return " ".join([word.capitalize() if word.lower() in [b.lower() for b in bible_books] else word for word in text.split()])

def apply_text_corrections(text):
    return correct_bible_books(spelling_corrections(text))

def split_text_for_display(text, max_length=90):
    """
    Split text for display using punctuation-aware chunking.
    Tries to break on punctuation or space near max length.
    """
    if len(text) <= max_length:
        return [text]
    
    # Split on sentence endings and punctuation
    sentences = re.split(r'(?<=[\.\?\!\,])\s+', text)
    chunks = []
    current = ""
    
    for sentence in sentences:
        if len(current) + len(sentence) <= max_length:
            current += (" " if current else "") + sentence
        else:
            if current:
                chunks.append(current.strip())
            current = sentence
    
    if current:
        chunks.append(current.strip())
    
    return chunks

def force_finalization():
    """
    Force finalization of current interim text by stopping and restarting recognition.
    This is called when the timer expires.
    """
    global finalization_timer, last_partial_time, user_recognizer
    
    if finalization_timer:
        finalization_timer.cancel()
        finalization_timer = None
    
    log_message(logging.INFO, "Forcing finalization due to timeout")
    
    try:
        # Force finalization by clearing interim text and updating display
        log_message(logging.INFO, "Forcing finalization - clearing interim text")
        # Update display with current history to show final state
        if user_caption_history.get("en-US"):
            # Send final caption update
            asyncio.run(send_caption_to_clients(
                {"en-US": user_caption_history["en-US"][-1] if user_caption_history["en-US"] else ""}, 
                languages=["en-US"], 
                caption_type="user"
            ))
        # Reset interim text
        user_last_text["en-US"] = ""
        last_partial_time = time.time()
    except Exception as e:
        log_message(logging.ERROR, f"Error during forced finalization: {e}")

def reset_finalization_timer():
    """
    Reset the finalization timer when new text is received.
    """
    global finalization_timer, last_partial_time
    
    last_partial_time = time.time()
    
    # Cancel existing timer if running
    if finalization_timer:
        finalization_timer.cancel()
    
    # Start new timer
    finalization_timer = Timer(MAX_FINALIZE_SECONDS, force_finalization)
    finalization_timer.start()
    log_message(logging.DEBUG, f"Finalization timer reset (will expire in {MAX_FINALIZE_SECONDS} seconds)")
    
    # Log current caption state for debugging
    if user_last_text.get("en-US"):
        log_message(logging.DEBUG, f"Current interim text: '{user_last_text['en-US'][:100]}...'")

# Production view processing (restored original functionality)
def process_production_speech_text(text=None, translations=None, is_recognized=False):
    global transcript, last_caption, production_caption, production_caption_history
    if translations is None:
        translations = {}
    if text:
        translations["en-US"] = text
    
    corrected_translations = {lang: apply_text_corrections(t) for lang, t in translations.items() if t}
    
    # Process English captions for production view
    if "en-US" in corrected_translations:
        corrected_text = corrected_translations["en-US"]
        
        # Use production settings for line wrapping
        prod_line_length = CONFIG.get("max_line_length", 90)
        
        if is_recognized:
            # For finalized captions, append to history
            if production_caption_history:
                # Add a space between existing text and new caption
                production_caption_history += " " + corrected_text
            else:
                production_caption_history = corrected_text
            
            # Wrap the accumulated text to ensure it fits on one line
            wrapped_lines = textwrap.wrap(production_caption_history, width=prod_line_length, break_long_words=False, break_on_hyphens=False)
            
            # Keep only the last line to maintain single-line display
            if wrapped_lines:
                production_caption_history = wrapped_lines[-1]
                production_caption = production_caption_history
            else:
                production_caption = production_caption_history
            
            # Update transcript for final captions
            transcript.append(corrected_text)
            if len(transcript) > CONFIG["max_transcript_lines"]:
                transcript = transcript[-CONFIG["max_transcript_lines"]:]
        else:
            # For interim captions, show history + current interim text
            if production_caption_history:
                interim_text = production_caption_history + " " + corrected_text
            else:
                interim_text = corrected_text
            
            # Wrap the interim text to ensure it fits on one line
            wrapped_lines = textwrap.wrap(interim_text, width=prod_line_length, break_long_words=False, break_on_hyphens=False)
            
            # Keep only the last line to maintain single-line display
            if wrapped_lines:
                production_caption = wrapped_lines[-1]
            else:
                production_caption = interim_text
    
    # Process translations (if any)
    translation_lines = {}
    for lang, text in corrected_translations.items():
        if lang != "en-US" and text:
            # For translations, use the same line wrapping logic
            prod_line_length = CONFIG.get("max_line_length", 90)
            wrapped_lines = textwrap.wrap(text, width=prod_line_length)
            translation_lines[lang] = wrapped_lines[-1] if wrapped_lines else ""
    
    # Combine English and translation captions
    production_caption_update_translations = {"en-US": production_caption}
    production_caption_update_translations.update(translation_lines)
    
    # Send updates immediately without debouncing for production view
    if "en-US" in production_caption_update_translations:
        try:
            asyncio.run(send_caption_to_clients(
                production_caption_update_translations, 
                languages=["en-US"], 
                caption_type="production"
            ))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send production caption: {e}")
    
    last_caption = production_caption
    return production_caption_update_translations



def process_user_speech_text(text=None, translations=None, is_recognized=False):
    global user_caption, user_caption_update_pending, user_caption_history, user_last_text
    if translations is None:
        translations = {}
    if text:
        translations["en-US"] = text
    
    log_message(logging.DEBUG, f"process_user_speech_text called: is_recognized={is_recognized}, translations={list(translations.keys())}")
    
    corrected_translations = {lang: apply_text_corrections(t) for lang, t in translations.items() if t}
    
    log_message(logging.DEBUG, f"corrected_translations: {list(corrected_translations.keys())}")
    
    # Use user settings for line wrapping and number of lines
    user_line_length = USER_SETTINGS.get("user_max_line_length", CONFIG["max_line_length"])
    user_max_lines = USER_SETTINGS.get("user_lines", 3)
    
    # Process each language
    for lang, corrected_text in corrected_translations.items():
        if is_recognized:
            # For final captions, add to history if it's new and not empty
            if corrected_text.strip() != "":
                # Only add to history if it's different from the last caption
                if not user_caption_history[lang] or corrected_text != user_caption_history[lang][-1]:
                    user_caption_history[lang].append(corrected_text)
                    # Keep only the last user_max_lines captions
                    if len(user_caption_history[lang]) > user_max_lines:
                        user_caption_history[lang] = user_caption_history[lang][-user_max_lines:]
                user_last_text[lang] = ""  # Clear interim text
        else:
            # For interim captions, update the current text
            # Check if this is the same as the remaining text from a recent finalization
            if user_last_text[lang] and corrected_text.startswith(user_last_text[lang]):
                log_message(logging.DEBUG, f"Interim text appears to be continuation of remaining text, updating: '{corrected_text[:50]}...'")
            
            user_last_text[lang] = corrected_text
            
            # Reset the finalization timer when new interim text is received
            reset_finalization_timer()
            

        
        # Build the display text from history and current interim text
        display_lines = []
        
        # Add all history items
        for caption in user_caption_history[lang]:
            # Wrap each caption according to line length
            wrapped_lines = textwrap.wrap(caption, width=user_line_length)
            display_lines.extend(wrapped_lines)
        
        # Add current interim caption if it exists and is not a duplicate of the last history item
        if user_last_text[lang] and user_last_text[lang].strip() != "":
            # Check if the interim text is already contained in the last history item
            last_history_item = user_caption_history[lang][-1] if user_caption_history[lang] else ""
            if not last_history_item or user_last_text[lang] not in last_history_item:
                wrapped_lines = textwrap.wrap(user_last_text[lang], width=user_line_length)
                display_lines.extend(wrapped_lines)
            else:
                log_message(logging.DEBUG, f"Skipping interim text as it's contained in last history item: '{user_last_text[lang][:50]}...'")
        
        # Join all lines with newlines for display
        user_caption = "\n".join(display_lines) if display_lines else ""
        
        log_message(logging.DEBUG, f"User caption updated for {lang}: {user_caption}")
    
    # Trigger debounced update for user captions
    if not user_caption_update_pending:
        user_caption_update_pending = True
        Timer(0.1, debounce_update_user_caption).start()  # Restored to original 100ms

def debounce_update_user_caption():
    global user_caption_update_pending, user_caption, user_caption_history, user_last_text
    if user_caption_update_pending:
        try:
            # Create a translations object with all languages and their histories
            all_translations = {}
            for lang, history in user_caption_history.items():
                if history:  # Only include languages that have history
                    # Join all history items with double newlines for better paragraph separation
                    all_translations[lang] = "\n\n".join(history)
            
            # Also include current interim text for each language
            for lang, interim_text in user_last_text.items():
                if interim_text and interim_text.strip() != "":
                    if lang in all_translations:
                        all_translations[lang] += "\n\n" + interim_text
                    else:
                        all_translations[lang] = interim_text
            
            if all_translations:
                log_message(logging.DEBUG, f"debounce_update_user_caption: sending translations for languages: {list(all_translations.keys())}")
                log_message(logging.DEBUG, f"debounce_update_user_caption: sample translation content: {list(all_translations.items())[:2]}")
                asyncio.run(send_caption_to_clients(all_translations, languages=list(all_translations.keys()), caption_type="user"))
                log_message(logging.DEBUG, f"Sent user captions with history for all languages: {list(all_translations.keys())}")
            else:
                log_message(logging.DEBUG, f"debounce_update_user_caption: no translations to send")
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send user caption: {e}")
        user_caption_update_pending = False

# -------------------------------------------------------------------
# Speech SDK Event Handlers
# -------------------------------------------------------------------
def on_production_speech_recognizing(evt):
    """Production recognizer - only sends to production view (optimized)"""
    global last_caption
    if evt.result.reason == speechsdk.ResultReason.RecognizingSpeech:
        text = evt.result.text
        process_production_speech_text(text=text, is_recognized=False)

def on_production_speech_recognized(evt):
    """Production recognizer - only sends to production view (optimized)"""
    global last_caption
    if evt.result.reason == speechsdk.ResultReason.RecognizedSpeech:
        text = evt.result.text
        process_production_speech_text(text=text, is_recognized=True)
    elif evt.result.reason == speechsdk.ResultReason.NoMatch:
        try:
            asyncio.run(send_caption_to_clients({"en-US": last_caption}, languages=["en-US"], caption_type="production"))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send production no-match caption: {e}")

def on_user_speech_recognizing(evt):
    """User recognizer - only processes when English is selected"""
    if evt.result.reason == speechsdk.ResultReason.RecognizingSpeech:
        text = evt.result.text
        # Only process for user view when English is selected
        if current_user_language == "en-US":
            process_user_speech_text(text=text, is_recognized=False)
        # Always process for production view
        process_production_speech_text(text=text, is_recognized=False)

def on_user_speech_recognized(evt):
    """User recognizer - only processes when English is selected"""
    if evt.result.reason == speechsdk.ResultReason.RecognizedSpeech:
        text = evt.result.text
        # Only process for user view when English is selected
        if current_user_language == "en-US":
            process_user_speech_text(text=text, is_recognized=True)
        # Always process for production view
        process_production_speech_text(text=text, is_recognized=True)
    elif evt.result.reason == speechsdk.ResultReason.NoMatch:
        try:
            user_caption_data = {"en-US": user_caption}
            asyncio.run(send_caption_to_clients(user_caption_data, languages=["en-US"], caption_type="user"))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send user no-match caption: {e}")

def map_azure_language_code(azure_code):
    """Map Azure Speech Service language codes to our dictionary codes"""
    mapping = {
        "en": "en-US",
        "es": "es-ES", 
        "fr": "fr-FR",
        "de": "de-DE",
        "zh-Hans": "zh-CN",
        "ja": "ja-JP",
        "ru": "ru-RU",
        "ar": "ar-EG"
    }
    return mapping.get(azure_code, azure_code)

def on_translation_recognizing(evt):
    """Translation recognizer - only processes when non-English is selected"""
    if evt.result.reason == speechsdk.ResultReason.TranslatingSpeech:
        translations = evt.result.translations
        # Add English from the original text if not already included
        translations_dict = dict(translations)
        if evt.result.text and "en-US" not in translations_dict:
            translations_dict["en-US"] = evt.result.text
        
        # Map Azure language codes to dictionary language codes
        mapped_translations = {}
        for azure_code, text in translations_dict.items():
            mapped_code = map_azure_language_code(azure_code)
            mapped_translations[mapped_code] = text
        
        log_message(logging.DEBUG, f"Translation recognizing: original_translations={list(translations_dict.keys())}, mapped_translations={list(mapped_translations.keys())}")
        
        # Only process translations for user view when non-English is selected
        if current_user_language != "en-US":
            log_message(logging.DEBUG, f"Processing translation for user view: {mapped_translations}")
            process_user_speech_text(translations=mapped_translations, is_recognized=False)
        else:
            log_message(logging.DEBUG, f"Skipping translation processing - user language is English")

def on_translation_recognized(evt):
    """Translation recognizer - only processes when non-English is selected"""
    if evt.result.reason == speechsdk.ResultReason.TranslatedSpeech:
        translations = evt.result.translations
        # Add English from the original text if not already included
        translations_dict = dict(translations)
        if evt.result.text and "en-US" not in translations_dict:
            translations_dict["en-US"] = evt.result.text
            
        # Map Azure language codes to dictionary language codes
        mapped_translations = {}
        for azure_code, text in translations_dict.items():
            mapped_code = map_azure_language_code(azure_code)
            mapped_translations[mapped_code] = text
            
        log_message(logging.DEBUG, f"Translation recognized: original_translations={list(translations_dict.keys())}, mapped_translations={list(mapped_translations.keys())}")
        
        # Only process final translations for user view when non-English is selected
        if current_user_language != "en-US":
            log_message(logging.DEBUG, f"Processing final translation for user view: {mapped_translations}")
            process_user_speech_text(translations=mapped_translations, is_recognized=True)
        else:
            log_message(logging.DEBUG, f"Skipping final translation processing - user language is English")
    elif evt.result.reason == speechsdk.ResultReason.NoMatch:
        try:
            # Only send to user view if non-English is selected
            if current_user_language != "en-US":
                user_caption_data = {"en-US": user_caption}
                asyncio.run(send_caption_to_clients(user_caption_data, languages=["en-US"], caption_type="user"))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send translation no-match caption: {e}")

def on_canceled(evt, recognizer_type):
    global is_recognizing
    if evt.reason == speechsdk.CancellationReason.Error:
        error_msg = f"Error in {recognizer_type}: {evt.error_details}"
        log_message(logging.ERROR, f"Speech service error: {error_msg}")
        try:
            asyncio.run(send_caption_to_clients({"en-US": error_msg}, languages=["en-US"], caption_type="production"))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send error caption: {e}")
        is_recognizing = False
    elif evt.reason == speechsdk.CancellationReason.EndOfStream:
        log_message(logging.INFO, f"Speech stream ended ({recognizer_type} canceled event).")
        try:
            asyncio.run(send_caption_to_clients({"en-US": "Stream ended."}, languages=["en-US"], caption_type="production"))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to send stream-ended caption: {e}")
        is_recognizing = False

# -------------------------------------------------------------------
# API Endpoints
# -------------------------------------------------------------------
@app.get("/get_ip")
async def get_ip():
    return {"ip": get_local_ip()}

@app.get("/")
async def get():
    return HTMLResponse(content=ROOT_TEMPLATE, status_code=200)

@app.get("/dashboard", dependencies=[Depends(get_current_username)])
async def dashboard():
    return HTMLResponse(content=DASHBOARD_TEMPLATE, status_code=200)

@app.get("/user")
async def preview():
    websocket_token = os.getenv("WEBSOCKET_TOKEN", "Northway12121")
    dictionary = load_dictionary()
    languages = dictionary.get("supported_languages", [])
    language_options = "".join([
        f'<option value="{lang["code"]}"{" selected" if lang["code"] == "en-US" else ""}>{lang["name"]}</option>\n' 
        for lang in languages
    ])
    return HTMLResponse(
        USER_TEMPLATE
        .replace("{{WEBSOCKET_TOKEN}}", websocket_token)
        .replace("{{LANGUAGE_OPTIONS}}", language_options)
    )

@app.get("/setup")
async def setup():
    return HTMLResponse(content=SETUP_TEMPLATE, status_code=200)

@app.get("/audio_devices")
async def get_audio_devices():
    try:
        if SOUNDDEVICE_AVAILABLE and sd:
            devices = sd.query_devices()
            return {"devices": devices}
        else:
            return {"devices": [], "error": "sounddevice not available"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to get audio devices: {e}")
        return {"devices": [], "error": str(e)}

# -------------------------------------------------------------------
# GitHub Update Endpoints
# -------------------------------------------------------------------
@app.get("/check_updates", dependencies=[Depends(get_current_username)])
async def check_updates():
    """Check for GitHub updates"""
    try:
        from github_updater import GitHubUpdater
        updater = GitHubUpdater()
        status = updater.get_update_status_display()
        return status
    except Exception as e:
        log_message(logging.ERROR, f"Error checking for updates: {e}")
        return {
            'status': 'error',
            'message': f'Error checking for updates: {str(e)}',
            'last_check': datetime.now().isoformat()
        }

@app.post("/perform_update", dependencies=[Depends(get_current_username)])
async def perform_update():
    """Perform GitHub update"""
    try:
        from github_updater import GitHubUpdater
        updater = GitHubUpdater()
        result = updater.perform_update()
        
        if result['status'] == 'success':
            log_message(logging.INFO, "GitHub update completed successfully")
            # Broadcast update notification to all clients
            await broadcast_update_notification(result)
        else:
            log_message(logging.ERROR, f"GitHub update failed: {result['message']}")
        
        return result
    except Exception as e:
        log_message(logging.ERROR, f"Error performing update: {e}")
        return {
            'status': 'error',
            'message': f'Error performing update: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }

@app.post("/setup")
async def set_setup(setup: dict):
    try:
        # Update config with setup data
        CONFIG.update(setup)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(CONFIG, f, indent=2)
        log_message(logging.INFO, f"Setup updated: {setup}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to update setup: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/settings", dependencies=[Depends(get_current_username)])
async def get_settings():
    return CONFIG

@app.post("/settings", dependencies=[Depends(get_current_username)])
async def set_settings(new_config: dict):
    try:
        CONFIG.update(new_config)
        with open(CONFIG_FILE, 'w') as f:
            json.dump(CONFIG, f, indent=2)
        log_message(logging.INFO, f"Settings updated: {new_config}")
        await broadcast_settings(new_config)
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to update settings: {e}")
        raise HTTPException(status_code=500, detail=str(e))

async def broadcast_settings(settings):
    for client in clients:
        try:
            await client.send_text(json.dumps({"type": "settings", "settings": settings}))
        except Exception as e:
            log_message(logging.ERROR, f"WebSocket send error: {e}")
            clients.remove(client)

@app.get("/schedule", dependencies=[Depends(get_current_username)])
async def get_schedule():
    return load_schedule()

@app.post("/schedule", dependencies=[Depends(get_current_username)])
async def set_schedule(schedule: dict):
    try:
        schedules = load_schedule()
        schedules.append(schedule)
        save_schedule(schedules)
        log_message(logging.INFO, f"Schedule added: {schedule}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to add schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/schedule", dependencies=[Depends(get_current_username)])
async def delete_schedule(date: str = Query(...)):
    try:
        schedules = load_schedule()
        schedules = [s for s in schedules if s.get('date') != date]
        save_schedule(schedules)
        log_message(logging.INFO, f"Schedule deleted for date: {date}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to delete schedule: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dictionary", dependencies=[Depends(get_current_username)])
async def get_dictionary():
    return load_dictionary()

@app.post("/dictionary/spelling", dependencies=[Depends(get_current_username)])
async def add_spelling_correction(correction: dict):
    try:
        dictionary = load_dictionary()
        dictionary["spelling_corrections"][correction["incorrect"]] = correction["correct"]
        save_dictionary(dictionary)
        log_message(logging.INFO, f"Spelling correction added: {correction}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to add spelling correction: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/dictionary/phrase", dependencies=[Depends(get_current_username)])
async def add_custom_phrase(phrase: dict):
    try:
        dictionary = load_dictionary()
        if phrase["phrase"] not in dictionary["custom_phrases"]:
            dictionary["custom_phrases"].append(phrase["phrase"])
            save_dictionary(dictionary)
            log_message(logging.INFO, f"Custom phrase added: {phrase}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to add custom phrase: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/dictionary/bible_book", dependencies=[Depends(get_current_username)])
async def add_bible_book(book: dict):
    try:
        dictionary = load_dictionary()
        if book["book"] not in dictionary["bible_books"]:
            dictionary["bible_books"].append(book["book"])
            save_dictionary(dictionary)
            log_message(logging.INFO, f"Bible book added: {book}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to add bible book: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/dictionary/spelling", dependencies=[Depends(get_current_username)])
async def delete_spelling_correction(incorrect: str = Query(...)):
    try:
        dictionary = load_dictionary()
        if incorrect in dictionary["spelling_corrections"]:
            del dictionary["spelling_corrections"][incorrect]
            save_dictionary(dictionary)
            log_message(logging.INFO, f"Spelling correction deleted: {incorrect}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to delete spelling correction: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/dictionary/phrase", dependencies=[Depends(get_current_username)])
async def delete_custom_phrase(phrase: str = Query(...)):
    try:
        dictionary = load_dictionary()
        if phrase in dictionary["custom_phrases"]:
            dictionary["custom_phrases"].remove(phrase)
            save_dictionary(dictionary)
            log_message(logging.INFO, f"Custom phrase deleted: {phrase}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to delete custom phrase: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.delete("/dictionary/bible_book", dependencies=[Depends(get_current_username)])
async def delete_bible_book(book: str = Query(...)):
    try:
        dictionary = load_dictionary()
        if book in dictionary["bible_books"]:
            dictionary["bible_books"].remove(book)
            save_dictionary(dictionary)
            log_message(logging.INFO, f"Bible book deleted: {book}")
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to delete bible book: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/dictionary_page", dependencies=[Depends(get_current_username)])
async def dictionary_page():
    return HTMLResponse(content=DICTIONARY_PAGE_TEMPLATE, status_code=200)

@app.post("/start_recognition", dependencies=[Depends(get_current_username)])
async def start_recognition_endpoint():
    try:
        await start_recognition()
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to start recognition: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/stop_recognition", dependencies=[Depends(get_current_username)])
async def stop_recognition_endpoint():
    try:
        await stop_recognition()
        return {"status": "success"}
    except Exception as e:
        log_message(logging.ERROR, f"Failed to stop recognition: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/recognition_status", dependencies=[Depends(get_current_username)])
async def recognition_status():
    global is_recognizing
    return {"is_recognizing": is_recognizing}

@app.get("/user_settings", dependencies=[Depends(get_current_username)])
async def get_user_settings():
    return USER_SETTINGS

@app.post("/user_settings", dependencies=[Depends(get_current_username)])
async def set_user_settings(settings: dict):
    global USER_SETTINGS
    valid_settings = {k: v for k, v in settings.items() if k in DEFAULT_USER_SETTINGS}
    USER_SETTINGS.update(valid_settings)
    save_user_settings(USER_SETTINGS)
    log_message(logging.INFO, f"User settings updated via API: {valid_settings}")
    try:
        await broadcast_user_settings(valid_settings)
        log_message(logging.DEBUG, f"User settings broadcasted to {len(clients)} clients")
    except Exception as e:
        log_message(logging.ERROR, f"Failed to broadcast user settings: {e}")
    return {"status": "success"}

@app.post("/set_user_language")
async def set_user_language(language_data: dict):
    global current_user_language
    language_code = language_data.get("language", "en-US")
    current_user_language = language_code
    log_message(logging.INFO, f"User language changed to: {language_code}")
    return {"status": "success", "current_language": current_user_language}

@app.post("/test_speech_processing")
async def test_speech_processing(test_data: dict):
    """Test endpoint to verify speech processing logic"""
    text = test_data.get("text", "Hello world")
    translations = test_data.get("translations", {"en-US": text, "es-ES": "Hola mundo"})
    is_recognized = test_data.get("is_recognized", True)
    
    log_message(logging.INFO, f"Testing speech processing with text: {text}, translations: {translations}, is_recognized: {is_recognized}")
    
    # Test the user speech processing function directly
    process_user_speech_text(text=text, translations=translations, is_recognized=is_recognized)
    
    return {"status": "success", "message": "Speech processing test completed"}

async def broadcast_user_settings(settings):
    for client in clients:
        try:
            await client.send_text(json.dumps({"type": "user_settings", "settings": settings}))
        except Exception as e:
            log_message(logging.ERROR, f"Failed to broadcast user settings to client: {e}")

@app.get("/favicon.ico")
async def favicon():
    return Response(content="", media_type="image/x-icon")

@app.get("/health")
async def health_check():
    global is_recognizing, last_partial_time, finalization_timer
    
    # Calculate time since last caption update
    time_since_last_update = time.time() - last_partial_time if last_partial_time else 0
    
    # Check if finalization timer is active
    timer_active = finalization_timer is not None
    
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "is_recognizing": is_recognizing,
        "time_since_last_caption": round(time_since_last_update, 2),
        "finalization_timer_active": timer_active,
        "current_interim_text": user_last_text.get("en-US", "")[:100] if user_last_text.get("en-US") else ""
    }

@app.websocket("/ws/captions")
async def websocket_endpoint(websocket: WebSocket, token: str = Query(...)):
    await websocket.accept()
    clients.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except Exception as e:
        log_message(logging.ERROR, f"WebSocket error: {e}")
    finally:
        if websocket in clients:
            clients.remove(websocket)

async def send_caption_to_clients(translations, languages, caption_type="production"):
    """
    Send captions to clients with proper structure for frontend (optimized)
    caption_type: "production", "user", "translation", or "user_translations"
    """
    if not clients:
        return  # No clients connected
    
    # Structure the data according to what the frontend expects
    if caption_type == "production":
        structured_data = {"production": translations}
    elif caption_type == "user":
        structured_data = {"user": translations}
    elif caption_type == "user_translations":
        structured_data = {"user_translations": translations}
    else:  # translation
        structured_data = {"production": translations}  # Translations go to production view
    
    # Prepare the message once
    message = json.dumps({
        "type": "caption", 
        "translations": structured_data, 
        "languages": languages
    })
    
    # Batch send to all clients
    disconnected_clients = []
    for client in clients:
        try:
            await client.send_text(message)
            log_message(logging.DEBUG, f"Sent {caption_type} caption to client: {client.client}")
        except Exception as e:
            log_message(logging.ERROR, f"WebSocket send error: {e}")
            disconnected_clients.append(client)
    
    # Remove disconnected clients
    for client in disconnected_clients:
        if client in clients:
            clients.remove(client)

# -------------------------------------------------------------------
# Speech Recognition Control
# -------------------------------------------------------------------
async def start_recognition():
    global is_recognizing, should_be_recognizing
    
    if is_recognizing:
        log_message(logging.INFO, "Speech recognition is already active")
        return
    
    # Always initialize recognizers to ensure they're properly set up
    log_message(logging.INFO, "Starting speech recognition - checking recognizer initialization")
    if not initialize_recognizers():
        log_message(logging.ERROR, "Failed to initialize speech recognizers")
        return
    
    try:
        # Set up event handlers
        if user_recognizer:
            user_recognizer.recognizing.connect(on_user_speech_recognizing)
            user_recognizer.recognized.connect(on_user_speech_recognized)
            user_recognizer.canceled.connect(lambda evt: on_canceled(evt, "User"))
        
        if translation_recognizer:
            translation_recognizer.recognizing.connect(on_translation_recognizing)
            translation_recognizer.recognized.connect(on_translation_recognized)
            translation_recognizer.canceled.connect(lambda evt: on_canceled(evt, "Translation"))
        
        # Start recognition with proper sequencing to avoid audio conflicts
        recognition_started = False
        
        # Start user recognizer first (it will handle both user and production views)
        if user_recognizer:
            try:
                user_recognizer.start_continuous_recognition()
                log_message(logging.INFO, "User recognizer started successfully")
                recognition_started = True
                
                # Small delay to allow first recognizer to establish audio connection
                time.sleep(0.5)
                
            except Exception as e:
                log_message(logging.ERROR, f"Failed to start user recognizer: {e}")
        
        # Start translation recognizer for multi-language support
        if translation_recognizer and recognition_started:
            try:
                translation_recognizer.start_continuous_recognition()
                log_message(logging.INFO, "Translation recognizer started successfully")
                
            except Exception as e:
                log_message(logging.ERROR, f"Failed to start translation recognizer: {e}")
        
        # Note: Production recognizer is not started to avoid audio conflicts
        # User recognizer now handles both user and production views
        
        is_recognizing = True
        should_be_recognizing = True
        log_message(logging.INFO, "Speech recognition started successfully")
        
    except Exception as e:
        log_message(logging.ERROR, f"Failed to start speech recognition: {e}")
        is_recognizing = False
        should_be_recognizing = False

async def stop_recognition():
    global is_recognizing, should_be_recognizing, finalization_timer
    
    if not is_recognizing:
        log_message(logging.INFO, "Speech recognition is not active")
        return
    
    try:
        # Cancel any pending finalization timer
        if finalization_timer:
            finalization_timer.cancel()
            finalization_timer = None
            log_message(logging.INFO, "Finalization timer cancelled")
        
        if user_recognizer:
            user_recognizer.stop_continuous_recognition()
        if translation_recognizer:
            translation_recognizer.stop_continuous_recognition()
        # Note: Production recognizer is not stopped since it's not started
        
        is_recognizing = False
        should_be_recognizing = False
        log_message(logging.INFO, "Speech recognition stopped")
        
    except Exception as e:
        log_message(logging.ERROR, f"Failed to stop speech recognition: {e}")

# -------------------------------------------------------------------
# Main Application
# -------------------------------------------------------------------
def run_fastapi():
    try:
        log_message(logging.INFO, "Starting FastAPI server...")
        uvicorn.run(
            app,
            host="0.0.0.0",
            port=8000,
            log_level="info"
        )
    except Exception as e:
        log_message(logging.ERROR, f"Failed to start FastAPI server: {e}")

if __name__ == "__main__":
    log_message(logging.INFO, "Caption Stable Docker Edition starting...")
    
    # Initialize speech recognizers during startup
    log_message(logging.INFO, "Initializing speech recognizers during startup...")
    if initialize_recognizers():
        log_message(logging.INFO, "Speech recognizers initialized successfully during startup")
    else:
        log_message(logging.WARNING, "Speech recognizers initialization failed during startup - will retry when recognition starts")
    
    # Start the FastAPI server
    run_fastapi() 