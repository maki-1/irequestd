# iRequest Dologon - Android App Wireframe Documentation

## Table of Contents
1. [App Overview](#app-overview)
2. [Screen Specifications](#screen-specifications)
3. [User Flows](#user-flows)
4. [Form Specifications](#form-specifications)
5. [Technical Specifications](#technical-specifications)
6. [UI/UX Guidelines](#uiux-guidelines)

---

## App Overview

### Project Name
**iRequest Dologon**

### App Type
- **Platform:** Android (native or cross-platform)
- **Target Audience:** Citizens of Dologon, Misamis Oriental (18+ years old)
- **Main Purpose:** Digital document request management system
- **Key Feature:** Face recognition + OTP verification

### Minimum Requirements
- **Android Version:** 6.0 (API level 23) and above
- **Screen Sizes:** 4.5" - 6.7" (phones)
- **RAM:** 2GB minimum
- **Storage:** 100MB free space
- **Permissions:** Camera, Storage, Internet, SMS/Email

### Core Documents Supported
1. **Barangay Clearance** - General purpose clearance
2. **Certificate of Residency** - Proof of residence in Dologon
3. **Certificate of Indigency** - Low-income certification

---

## Screen Specifications

### SCREEN 1: SPLASH SCREEN
**Purpose:** Initial app launch screen
**Duration:** 2-3 seconds (animated)

**Layout Components:**
```
┌─────────────────────────────────┐
│                                 │
│    [Gradient Background]        │
│                                 │
│      📋                         │
│   iRequest Dologon              │
│   Get your documents faster     │
│                                 │
│    ● ● ●  (Loading dots)       │
│                                 │
└─────────────────────────────────┘
```

**Design:**
- Background: Linear gradient (info color)
- Large app icon (64px)
- App name in white text
- Subtitle tagline
- Loading animation (3 pulsing dots)

**Interactions:**
- Auto-navigates to carousel/login after splash completes
- No user input required

**Duration:** 2-3 seconds

---

### SCREEN 2: ONBOARDING CAROUSEL
**Purpose:** Introduce app features to first-time users
**Flow:** 3 slides (swipeable)

**Slide 1: Quick Document Requests**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│         📄                      │
│   Quick Document Requests       │
│                                 │
│   Get your barangay clearance,  │
│   certificate of residency,     │
│   and certificate of indigency  │
│   in minutes, not days.         │
│                                 │
│      ● ○ ○  (Indicators)       │
│                                 │
│    [Next Button]                │
│    [Skip Button]                │
│                                 │
└─────────────────────────────────┘
```

**Slide 2: Easy Verification**
- Same layout with different icon (✓)
- Tagline: "Complete verification in 3 simple steps"
- Details about quick verification process

**Slide 3: Real-time Tracking**
- Same layout with different icon (📱)
- Tagline: "Track your requests in real-time"
- Details about status updates

**Navigation:**
- Horizontal swipe to navigate slides
- Dot indicators showing current slide
- "Next" button to advance
- "Skip" button to bypass carousel

**Design Elements:**
- Large icon (80px)
- Centered layout
- Clear typography
- Two call-to-action buttons

---

### SCREEN 3: LOGIN SCREEN
**Purpose:** Allow existing users to access their accounts
**Access:** After splash/carousel skip

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│      Welcome Back               │
│                                 │
│  ┌──────────────────────────┐   │
│  │ Email or Username        │   │
│  │ [...................]    │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │ Password                 │   │
│  │ [...................]    │   │
│  └──────────────────────────┘   │
│                                 │
│  ┌──────────────────────────┐   │
│  │      Login Button        │   │
│  └──────────────────────────┘   │
│                                 │
│─────────────────────────────────│
│ Don't have account? Sign Up     │
│ Forgot password?                │
│                                 │
└─────────────────────────────────┘
```

**Form Fields:**
1. **Email or Username** (text input)
   - Placeholder: "Enter email"
   - Required field
   - Validation: Non-empty

2. **Password** (password input)
   - Placeholder: "Enter password"
   - Required field
   - Show/hide toggle
   - Validation: Non-empty

**Buttons:**
- **Login** - Submits credentials
- **Sign Up** - Navigate to sign up screen
- **Forgot Password** - Password recovery flow

**Validations:**
- Username/email must not be empty
- Password must not be empty
- Error messages for invalid credentials

**After Submit:**
- OTP verification screen (Screen 4)

---

### SCREEN 4: LOGIN OTP VERIFICATION
**Purpose:** Verify login with OTP
**Triggered After:** Login form submission

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Verify Identity          │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ OTP sent to +63 9XX XXXX XXX│ │
│ │ and email                   │ │
│ └─────────────────────────────┘ │
│                                 │
│ Enter OTP Code                  │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│ │ 0  │ │ 0  │ │ 0  │ │ 0  │   │
│ └────┘ └────┘ └────┘ └────┘   │
│ ┌────┐ ┌────┐                  │
│ │ 0  │ │ 0  │                  │
│ └────┘ └────┘                  │
│                                 │
│ Didn't receive? Resend (30s)    │
│                                 │
│ ┌──────────────────────────────┐│
│ │  Verify & Login              ││
│ └──────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**Components:**
1. **Header Bar**
   - Back button (returns to login)
   - Title: "Verify Identity"

2. **Info Banner**
   - Shows phone and email for OTP delivery
   - Blue background, info color

3. **OTP Input Fields**
   - 6 individual digit fields
   - Auto-focus on next field after digit entry
   - Input type: numeric only
   - Size: 44px × 44px each
   - Spacing: 8px gap

4. **Resend Option**
   - Text: "Didn't receive? Resend (30s)"
   - Countdown timer (30 seconds)
   - Becomes clickable after timer expires
   - Allows 3 resend attempts

5. **Submit Button**
   - Label: "Verify & Login"
   - Full width
   - Disabled until all 6 digits entered

**User Interactions:**
- Tap any digit field to start typing
- Auto-advance to next field after entering digit
- Can backspace to previous field
- Paste OTP if copied
- Auto-submit after final digit (optional)

**Validation:**
- Each field: 0-9 only
- All 6 fields required
- Timer prevents spam submissions

**Success Flow:**
- Verify OTP with backend
- Navigate to Dashboard (Screen 12)

**Error Handling:**
- Invalid OTP: Show error message
- Expired OTP: Offer resend
- Max attempts exceeded: Lock for 10 minutes

---

### SCREEN 5: SIGN UP FORM (5 FIELDS)
**Purpose:** Register new users
**Required Fields:** 5 only

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Create Account           │
│                                 │
│ Fill in your basic information  │
│                                 │
│ 1. Username *                   │
│ ┌──────────────────────────────┐│
│ │ 6-20 characters            │ ││
│ └──────────────────────────────┘│
│ Available ✓                      │
│                                 │
│ 2. Email *                      │
│ ┌──────────────────────────────┐│
│ │ your@email.com             │ ││
│ └──────────────────────────────┘│
│                                 │
│ 3. Contact Number *             │
│ ┌──────────────────────────────┐│
│ │ +63 9XX XXXX XXX           │ ││
│ └──────────────────────────────┘│
│                                 │
│ 4. Password *                   │
│ ┌──────────────────────────────┐│
│ │ Min 8 chars                │ ││
│ └──────────────────────────────┘│
│ Strength: █████░░░░  Strong     │
│                                 │
│ 5. Confirm Password *           │
│ ┌──────────────────────────────┐│
│ │ Repeat password            │ ││
│ └──────────────────────────────┘│
│                                 │
│ [Next: Face Recognition]        │
│                                 │
│ Have account? Login             │
│                                 │
└─────────────────────────────────┘
```

**Field 1: Username**
- Type: Text input
- Placeholder: "6-20 characters"
- Min length: 6 characters
- Max length: 20 characters
- Allowed: Alphanumeric + underscore
- Real-time validation:
  - Shows "Available ✓" when unique
  - Shows "Taken ✗" when duplicate
  - API call on blur/after 500ms delay

**Field 2: Email**
- Type: Email input
- Placeholder: "your@email.com"
- Validation: RFC 5322 format
- Must be unique in system
- Verification: OTP will be sent

**Field 3: Contact Number**
- Type: Tel input
- Placeholder: "+63 9XX XXXX XXX"
- Format: Philippine mobile numbers
- Valid: +63 9xxxxxxxxxx or 09xxxxxxxxxx
- Verification: SMS OTP will be sent
- Auto-format as user types

**Field 4: Password**
- Type: Password input
- Placeholder: "Min 8 characters"
- Min length: 8 characters
- Requirements:
  - At least 1 uppercase letter (A-Z)
  - At least 1 lowercase letter (a-z)
  - At least 1 number (0-9)
  - Recommended: 1 special character
- Show/hide toggle
- Strength indicator:
  - Weak: 1-2 requirements (red)
  - Medium: 3 requirements (orange)
  - Strong: 4+ requirements (green)
- Visual strength bar (4 segments)

**Field 5: Confirm Password**
- Type: Password input
- Placeholder: "Repeat password"
- Must match Field 4 exactly
- Show/hide toggle
- Real-time validation:
  - Shows checkmark when matches
  - Shows error when doesn't match
- Enable submit button only when valid

**Buttons:**
- **Next: Face Recognition** - Proceed to Screen 6
  - Disabled until all fields valid
  - Shows loading state on click

**Secondary Actions:**
- **Have account? Login** - Navigate back to Screen 3

**Validation Summary:**
```
FIELD               REQUIRED  MIN   MAX   FORMAT
────────────────────────────────────────────────
Username            Yes       6     20    Alphanumeric+_
Email               Yes       -     -     valid@email.com
Contact Number      Yes       11    13    Philippine format
Password            Yes       8     -     Complex (4 types)
Confirm Password    Yes       8     -     Must match password
```

**Error Messages:**
- "Username already taken"
- "Invalid email format"
- "Phone number format incorrect"
- "Password too weak"
- "Passwords don't match"
- "All fields required"

**Success:**
- All validations pass
- Navigate to Screen 6 (Face Recognition)

---

### SCREEN 6: FACE RECOGNITION
**Purpose:** Capture user's face for verification
**Tech:** ML Kit Face Detection / AWS Rekognition

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Face Recognition         │
│                                 │
│ ┌─────────────────────────────┐ │
│ │                             │ │
│ │      [Camera Preview]       │ │
│ │      (Video Feed)           │ │
│ │                             │ │
│ │    Position your face       │ │
│ │      in the frame           │ │
│ │                             │ │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ ✓ Good lighting required    │ │
│ │ ✓ No glasses or coverings   │ │
│ │ ✓ Face straight to camera   │ │
│ └─────────────────────────────┘ │
│                                 │
│ [Start Capture]                 │
│ [Retake]                        │
│                                 │
└─────────────────────────────────┘
```

**Components:**

1. **Camera Preview Area**
   - Full width video feed
   - Height: 180px
   - Aspect ratio: Maintain device ratio
   - Circular overlay for face positioning
   - Frame indicator

2. **Instructions Banner**
   - Info background color
   - Checklist of requirements
   - Clear, simple language

3. **Buttons:**
   - **Start Capture** - Initiates face scan
   - **Retake** - Re-open camera

**Face Recognition Process:**

Step 1: User taps "Start Capture"
- Camera activates
- User positions face in frame
- Real-time face detection runs

Step 2: Liveness Detection
- System checks for:
  - Face is visible
  - Eyes are open
  - Face fills frame adequately
  - Lighting is sufficient

Step 3: Instructions Given
- "Look directly at camera"
- "Blink your eyes" (if needed)
- "Turn head slowly left-right" (if needed)

Step 4: Capture & Verification
- When good face detected:
  - Auto-captures high-quality image
  - Shows confirmation
  - "Capture successful" message
  
Step 5: Options:
- **Continue** → Next screen (Screen 7: OTP)
- **Retake** → New capture

**Validation Rules:**
- Face must be clearly visible
- No glasses (warn if detected)
- No head coverings
- Good lighting
- Face fills minimum 30% of frame
- Frontal view (±30° angle)
- Liveness check passed

**Error Handling:**
- "Face not detected" - Move closer
- "Face too small" - Move closer
- "Multiple faces detected" - Single person only
- "Poor lighting" - Move to better light
- "Face at wrong angle" - Look straight ahead
- "Liveness check failed" - Blink and try again

**Maximum Attempts:** 5
- If 5 attempts fail: Option to skip or try later
- Can proceed with manual verification

---

### SCREEN 7: SIGN UP OTP VERIFICATION
**Purpose:** Verify email and SMS for new account
**Triggered After:** Face recognition (Screen 6)

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│  Verify Your Account            │
│                                 │
│ We sent OTP codes to your email │
│ and phone                       │
│                                 │
│ Email OTP                       │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│ │ 0  │ │ 0  │ │ 0  │ │ 0  │   │
│ └────┘ └────┘ └────┘ └────┘   │
│ ┌────┐ ┌────┐                  │
│ │ 0  │ │ 0  │                  │
│ └────┘ └────┘                  │
│                                 │
│ SMS OTP                         │
│ ┌────┐ ┌────┐ ┌────┐ ┌────┐   │
│ │ 0  │ │ 0  │ │ 0  │ │ 0  │   │
│ └────┘ └────┘ └────┘ └────┘   │
│ ┌────┐ ┌────┐                  │
│ │ 0  │ │ 0  │                  │
│ └────┘ └────┘                  │
│                                 │
│ ┌──────────────────────────────┐│
│ │  Next: Complete Profile      ││
│ └──────────────────────────────┘│
│                                 │
└─────────────────────────────────┘
```

**Components:**

1. **Title & Instructions**
   - "Verify Your Account"
   - "We sent OTP codes to your email and phone"

2. **Email OTP Section**
   - 6 digit input fields
   - Auto-focus behavior
   - 10-minute expiration

3. **SMS OTP Section**
   - 6 digit input fields
   - Auto-focus behavior
   - 10-minute expiration

4. **Submit Button**
   - "Next: Complete Profile"
   - Disabled until both OTPs valid
   - Shows loading state

**User Flow:**
1. Enter Email OTP (6 digits)
2. Enter SMS OTP (6 digits)
3. Tap "Next: Complete Profile"
4. Backend verifies both OTPs
5. Navigate to Screen 8 (Step 1: Profile)

**Validation:**
- Both OTPs must be provided
- Each OTP must be exactly 6 digits
- Numeric input only

**Error Handling:**
- Invalid OTP: Show error message
- Expired OTP: Show "Expired - Request new"
- Mismatch: Show "Incorrect OTP"

**Resend Logic:**
- "Resend Email OTP" (after 1st resend)
- "Resend SMS OTP" (after 1st resend)
- Max 3 resends per field
- 30-second cooldown between resends

---

### SCREEN 8: STEP 1 - DEMOGRAPHIC PROFILE
**Purpose:** Collect personal identification information
**Step:** 1 of 3 verification steps

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Step 1: Demographic      │
│                                 │
│ Progress Indicator:             │
│ ①────② ───③                    │
│ 1:Prof 2:Educ 3:ID             │
│                                 │
│ Full Legal Name *               │
│ ┌──────────────────────────────┐│
│ │ As in documents            │ ││
│ └──────────────────────────────┘│
│                                 │
│ Current Address *               │
│ ┌──────────────────────────────┐│
│ │ Complete address in Dologon│ ││
│ └──────────────────────────────┘│
│                                 │
│ Age * │ Gender *                │
│ ┌──────┐ ┌──────────────────────┐
│ │ 18+ │ │ Select            ▼ │
│ └──────┘ └──────────────────────┐
│                                 │
│ Years at Address *              │
│ ┌──────────────────────────────┐│
│ │ Select                    ▼ ││
│ └──────────────────────────────┘│
│                                 │
│ Mother's Full Name *            │
│ ┌──────────────────────────────┐│
│ │ Full name                  │ ││
│ └──────────────────────────────┘│
│                                 │
│ Father's Full Name *            │
│ ┌──────────────────────────────┐│
│ │ Full name                  │ ││
│ └──────────────────────────────┘│
│                                 │
│ [Continue to Step 2]            │
│                                 │
└─────────────────────────────────┘
```

**Progress Indicator:**
- 3-step visual tracker
- Circle with number
- Connected by lines
- Current step highlighted (blue)
- Completed steps: Green with checkmark
- Future steps: Gray

**Form Fields:**

**1. Full Legal Name**
- Type: Text
- Placeholder: "As in documents"
- Required: Yes
- Max length: 100 characters
- Validation: Not empty, letters + spaces only

**2. Current Address**
- Type: Text
- Placeholder: "Complete address in Dologon"
- Required: Yes
- Max length: 200 characters
- Must include: Street, Barangay, City, ZIP
- Validation: Must be in Dologon

**3. Age**
- Type: Number
- Placeholder: "18+"
- Required: Yes
- Min: 18
- Max: 120
- Validation: Must be 18 or older

**4. Gender**
- Type: Dropdown/Picker
- Options:
  - Select (default)
  - Male
  - Female
  - Other
- Required: Yes
- Default: "Select"

**5. Years at Address**
- Type: Dropdown
- Options:
  - Select (default)
  - 6 months - 1 year
  - 1 - 3 years
  - 3 - 5 years
  - 5+ years
- Required: Yes
- Min requirement: 6 months

**6. Mother's Full Name**
- Type: Text
- Placeholder: "Full name"
- Required: Yes
- Max length: 100 characters
- Validation: Not empty, letters + spaces

**7. Father's Full Name**
- Type: Text
- Placeholder: "Full name"
- Required: Yes
- Max length: 100 characters
- Validation: Not empty, letters + spaces

**Navigation:**
- **[Continue to Step 2]** - Validate & advance
  - Disabled until all required fields valid
  - Shows loading on click
- **[Back]** - Return to previous screen
  - Asks for confirmation if changes made
  - Warns data won't be saved

**Validation Rules:**
```
FIELD               REQUIRED  MIN   MAX   FORMAT
──────────────────────────────────────────────
Full Legal Name     Yes       2     100   Letters + spaces
Current Address     Yes       10    200   Text, Dologon only
Age                 Yes       18    120   Number
Gender              Yes       -     -     Dropdown select
Years at Address    Yes       -     -     Dropdown select
Mother's Name       Yes       2     100   Letters + spaces
Father's Name       Yes       2     100   Letters + spaces
```

**Error Messages:**
- "Field required"
- "Invalid age (must be 18+)"
- "Address must be in Dologon"
- "Invalid format"

**Save Behavior:**
- Data saved locally while filling
- On "Continue": Submitted to backend
- If error: Show message, keep form

---

### SCREEN 9: STEP 2 - EDUCATIONAL ATTAINMENT
**Purpose:** Collect educational background
**Step:** 2 of 3 verification steps

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Step 2: Education        │
│                                 │
│ Progress Indicator:             │
│ ✓────②────③                    │
│ 1:Prof 2:Educ 3:ID             │
│                                 │
│ Highest Education Level         │
│ ┌──────────────────────────────┐│
│ │ Select                    ▼ ││
│ └──────────────────────────────┘│
│                                 │
│ School/Institution              │
│ ┌──────────────────────────────┐│
│ │ Name of school             │ ││
│ └──────────────────────────────┘│
│                                 │
│ Year Graduated/Enrolled         │
│ ┌──────────────────────────────┐│
│ │ e.g., 2020                 │ ││
│ └──────────────────────────────┘│
│                                 │
│ Course/Strand                   │
│ ┌──────────────────────────────┐│
│ │ If applicable              │ ││
│ └──────────────────────────────┘│
│                                 │
│ Educational Certificate         │
│ ┌──────────────────────────────┐│
│ │           📄                │ │
│ │  Tap to upload (Optional)  │ │
│ └──────────────────────────────┘│
│                                 │
│ [Continue to Step 3]            │
│                                 │
└─────────────────────────────────┘
```

**Form Fields:**

**1. Highest Education Level**
- Type: Dropdown
- Options:
  - Select (default)
  - Elementary
  - High School
  - Vocational
  - Bachelor's Degree
  - Master's Degree
  - PhD
  - Other
- Required: No (but recommended)

**2. School/Institution**
- Type: Text
- Placeholder: "Name of school"
- Max length: 150 characters
- Required: No

**3. Year Graduated/Enrolled**
- Type: Number
- Placeholder: "e.g., 2020"
- Min: 1950
- Max: Current year + 10
- Required: No
- Format: YYYY

**4. Course/Strand**
- Type: Text
- Placeholder: "If applicable"
- Max length: 100 characters
- Required: No

**5. Educational Certificate**
- Type: File upload
- Allowed formats: PDF, JPG, PNG
- Max size: 5MB
- Required: No (Optional)
- Drag-and-drop support
- Camera capture option

**File Upload Component:**
```
┌──────────────────────────────┐
│          📄                  │
│  Tap to upload (Optional)    │
│                              │
│  Formats: PDF, JPG, PNG      │
│  Max size: 5MB               │
└──────────────────────────────┘
```

**Interactions:**
- Tap to open file picker
- Camera option available
- Long-press for options menu
- Show file preview after selection
- Remove button to clear selection

**Navigation:**
- **[Continue to Step 3]** - Advance to next step
  - All optional fields, so always enabled
  - Shows loading on click
- **[Back]** - Return to Step 1
  - Can navigate without saving

**Validation Rules:**
```
FIELD                    REQUIRED  MIN  MAX   FORMAT
─────────────────────────────────────────────────
Highest Education        No        -    -     Dropdown select
School/Institution       No        -    150   Text
Year Graduated/Enrolled  No        1950 2035  YYYY
Course/Strand            No        -    100   Text
Educational Certificate  No        -    5MB   PDF/JPG/PNG
```

**Error Messages:**
- "File size exceeds 5MB"
- "Invalid file format"
- "Year must be between 1950 and 2035"

---

### SCREEN 10: STEP 4 - ID VERIFICATION
**Purpose:** Collect identity documents
**Step:** 3 of 3 verification steps

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Step 3: ID Verification  │
│                                 │
│ Progress Indicator:             │
│ ✓────✓────③                    │
│ 1:Prof 2:Educ 3:ID             │
│                                 │
│ Select ID Type *                │
│ ○ Primary ID (1 required)       │
│ ○ Secondary ID (2 required)     │
│                                 │
│ Choose ID *                     │
│ ┌──────────────────────────────┐│
│ │ Select ID                 ▼ ││
│ └──────────────────────────────┘│
│                                 │
│ Front of ID                     │
│ ┌──────────────────────────────┐│
│ │           📸                │ │
│ │    Tap to upload           │ │
│ └──────────────────────────────┘│
│                                 │
│ Back of ID                      │
│ ┌──────────────────────────────┐│
│ │           📸                │ │
│ │    Tap to upload           │ │
│ └──────────────────────────────┘│
│                                 │
│ [Submit for Verification]       │
│                                 │
└─────────────────────────────────┘
```

**Form Fields:**

**1. Select ID Type**
- Type: Radio buttons
- Options:
  - Primary ID (1 required)
  - Secondary ID (2 required)
- Required: Yes
- Selection determines dropdown options

**2. Choose ID**
- Type: Dropdown (dynamic based on type)

**PRIMARY ID OPTIONS:**
- Passport
- National ID (PhilID)
- UMID (Unified Multi-Purpose ID)
- Driver's License
- PRC License (Professional Regulation Commission)
- Senior Citizen ID
- PWD ID (Person with Disability ID)

**SECONDARY ID OPTIONS:**
- Voter's ID
- Postal ID
- School ID
- Company/Employment ID
- Barangay ID
- Birth Certificate (Short Form)
- Marriage Certificate

- Required: Yes
- Default: "Select ID"

**3. Front of ID**
- Type: Image upload
- Allowed formats: JPG, PNG
- Max size: 5MB
- Required: Yes
- Camera capture support
- Auto-crop option

**4. Back of ID**
- Type: Image upload
- Allowed formats: JPG, PNG
- Max size: 5MB
- Required: Yes (except single-sided docs)
- Camera capture support

**Image Quality Requirements:**
- Clear and legible text
- No glare or shadows
- Complete document visible
- All 4 corners visible
- Proper lighting
- Recent/valid document

**Navigation:**
- **[Submit for Verification]** - Final submission
  - All fields must be valid
  - Shows loading state
  - Uploads to backend
- **[Back]** - Return to Step 2

**Validation Rules:**
```
FIELD              REQUIRED  FORMAT    SIZE
──────────────────────────────────────────
ID Type            Yes       Dropdown  -
Choose ID          Yes       Dropdown  -
Front of ID        Yes       JPG/PNG   5MB
Back of ID         Yes       JPG/PNG   5MB
```

**Error Messages:**
- "Please select ID type"
- "Please choose an ID"
- "Please upload front of ID"
- "Please upload back of ID"
- "Image file too large (max 5MB)"
- "Invalid file format"
- "Image quality too low"

**Success Flow:**
- All validations pass
- Data submitted to backend
- Navigate to Screen 11 (Verification Waiting)

---

### SCREEN 11: VERIFICATION WAITING
**Purpose:** Show submission confirmation & waiting status
**Triggered After:** All verification steps submitted

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│          ⏳                      │
│                                 │
│  Verification in Progress       │
│                                 │
│  Your documents have been       │
│  submitted to our secretary     │
│  for verification.              │
│                                 │
│ ┌─────────────────────────────┐ │
│ │  Expected Time:             │ │
│ │  24 - 72 Hours              │ │
│ └─────────────────────────────┘ │
│                                 │
│ Submitted Information            │
│ ✓ Demographic Profile           │
│ ✓ Educational Attainment        │
│ ✓ ID Documents                  │
│ ✓ Face Recognition              │
│                                 │
│ [Check Status]                  │
│                                 │
│ You'll receive SMS and Email    │
│ notification when approved      │
│                                 │
└─────────────────────────────────┘
```

**Components:**

1. **Status Icon**
   - Large hourglass emoji (⏳)
   - Yellow/warning color background circle

2. **Status Title**
   - "Verification in Progress"

3. **Description**
   - "Your documents have been submitted to our secretary for verification."

4. **Timeline Box**
   - Expected time: 24-72 hours
   - Secondary background color

5. **Submitted Data Checklist**
   - Demographic Profile - ✓
   - Educational Attainment - ✓
   - ID Documents - ✓
   - Face Recognition - ✓

6. **Buttons**
   - **[Check Status]** - View submission details
     - Opens dialog with submission info
     - Date/time submitted
     - Submitted data review
   - **[Back to Home]** - Navigate to login/onboarding
     - User will login again when approved

**Info Banner**
- Text: "You'll receive SMS and Email notification when approved"
- Small, informational text

**What Happens Next:**
- Secretary reviews documents (24-72 hours)
- If approved: Account activated
  - User gets SMS/Email notification
  - Can login to dashboard
- If rejected: User gets notification with feedback
  - Can resubmit with corrections

**Background Behavior:**
- Push notification when status changes
- In-app notification badge
- Email notification sent

---

### SCREEN 12: DASHBOARD (HOME)
**Purpose:** Main hub after account verification
**Access:** After account approved & login

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Header - Info Color]           │
│ Welcome back                    │
│ John Doe              👤        │
├─────────────────────────────────┤
│                                 │
│ SERVICES                        │
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │   📋    │ │    🏠    │      │
│ │Barangay │ │Residency │      │
│ │Clearance│ │          │      │
│ └──────────┘ └──────────┘      │
│                                 │
│ ┌──────────┐ ┌──────────┐      │
│ │    🆔    │ │    📂    │      │
│ │Indigency │ │  Requests│      │
│ └──────────┘ └──────────┘      │
│                                 │
│ ACCOUNT STATUS                  │
│ ✓ Account Verified              │
│                                 │
│ RECENT ACTIVITY                 │
│ Account Verified                │
│ 1 hour ago                      │
│                                 │
├─────────────────────────────────┤
│ 🏠 Home │ 📂 Request │ ⚙️ Sett│
└─────────────────────────────────┘
```

**Header Section:**
- Background: Info color
- Greeting: "Welcome back"
- User's first name displayed
- Profile icon/avatar (circle, 40×40px)
- User can tap to view profile

**Quick Actions Grid:**
- 4 cards in 2×2 grid
- Each card tappable

**Card 1: Barangay Clearance**
- Icon: 📋
- Title: "Barangay Clearance"
- Action: Opens document request (Screen 13)

**Card 2: Certificate of Residency**
- Icon: 🏠
- Title: "Residency"
- Action: Opens document request

**Card 3: Certificate of Indigency**
- Icon: 🆔
- Title: "Indigency"
- Action: Opens document request

**Card 4: My Requests**
- Icon: 📂
- Title: "Requests"
- Action: Shows my requests screen (Screen 14)

**Account Status Section**
- Title: "ACCOUNT STATUS"
- Status badge: "✓ Account Verified" (green)
- Can show alerts here if needed

**Recent Activity Timeline**
- Title: "RECENT ACTIVITY"
- Last 5 activities listed
- Format: "Activity Name" + "Time ago"
- Left border accent (info color)
- Examples:
  - "Account Verified" - 1 hour ago
  - "Documents Submitted" - 2 days ago

**Bottom Navigation Bar**
- 3 tabs:
  - 🏠 Home (current)
  - 📂 Request (Screen 13)
  - ⚙️ Settings (Screen 15)
- Active tab highlighted
- Inactive tabs muted

**Interactions:**
- Tap service card → Request document
- Tap "My Requests" → View all requests
- Tap avatar → View/edit profile
- Tap bottom nav → Navigate

**Notifications:**
- Badge on "My Requests" if new status
- Red dot on bell icon if new notification

---

### SCREEN 13: REQUEST DOCUMENT
**Purpose:** Submit new document request
**Access:** From dashboard quick actions or menu

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│ [Back] Request Document         │
│                                 │
│ Select Document Type *          │
│ ○ Barangay Clearance           │
│ ○ Certificate of Residency     │
│ ○ Certificate of Indigency     │
│                                 │
│ Purpose of Document *           │
│ ┌──────────────────────────────┐│
│ │ Select purpose            ▼ ││
│ └──────────────────────────────┘│
│ Options:                        │
│ • Employment                    │
│ • Travel                        │
│ • Bank Requirements             │
│ • Scholarship                   │
│ • Government Assistance         │
│ • Other                         │
│                                 │
│ Additional Details              │
│ ┌──────────────────────────────┐│
│ │ Any additional info...     │ ││
│ │                            │ ││
│ └──────────────────────────────┘│
│ (Multi-line text area)          │
│                                 │
│ Delivery Method *               │
│ ○ Pick up at Barangay Office   │
│ ○ Digital (Email)              │
│                                 │
│ [Submit Request]                │
│                                 │
└─────────────────────────────────┘
```

**Form Fields:**

**1. Select Document Type**
- Type: Radio buttons
- Required: Yes
- Options:
  - Barangay Clearance
  - Certificate of Residency
  - Certificate of Indigency

**2. Purpose of Document**
- Type: Dropdown
- Required: Yes
- Options:
  - Select purpose (default)
  - Employment
  - Travel
  - Bank Requirements
  - Scholarship
  - Government Assistance
  - Other

**3. Additional Details**
- Type: Text area
- Placeholder: "Any additional information..."
- Required: No
- Max length: 500 characters
- Shows character count
- Multi-line input

**4. Delivery Method**
- Type: Radio buttons
- Required: Yes
- Options:
  - Pick up at Barangay Office
  - Digital (Email)

**Buttons:**
- **[Submit Request]** - Submit form
  - Disabled until required fields filled
  - Shows loading state
  - Success message on submit

**Navigation:**
- **[Back]** - Return to dashboard

**Validation Rules:**
```
FIELD              REQUIRED  FORMAT
───────────────────────────────────
Document Type      Yes       Radio select
Purpose            Yes       Dropdown
Additional Details No        Text (500 max)
Delivery Method    Yes       Radio select
```

**Success Flow:**
- Submit request
- Show confirmation message
- Navigate to Screen 14 (My Requests)
- New request appears in list

**Error Handling:**
- Show validation error if fields missing
- Show error if submission fails
- Allow retry

---

### SCREEN 14: MY REQUESTS
**Purpose:** View all submitted document requests
**Access:** From dashboard or bottom nav

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│  My Requests                    │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 📋 Barangay Clearance     ┃ │
│ │ REQ-001                   ┃ │
│ │                           ✓│
│ │ Submitted: Mar 10, 2024     │
│ │ [Download Document]         │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🏠 Cert. of Residency     ┃ │
│ │ REQ-002                   ⏳│
│ │                             │
│ │ Submitted: Mar 11, 2024     │
│ │ Est: Mar 13, 2024           │
│ └─────────────────────────────┘ │
│                                 │
│ ┌─────────────────────────────┐ │
│ │ 🆔 Cert. of Indigency     ┃ │
│ │ REQ-003                   ⏲ │
│ │                             │
│ │ Submitted: Mar 12, 2024     │
│ └─────────────────────────────┘ │
│                                 │
├─────────────────────────────────┤
│ 🏠 Home │ 📂 Requests │ ⚙️ Sett│
└─────────────────────────────────┘
```

**Request List Layout:**
- Scrollable list
- Each request = card
- Cards stacked vertically
- 12px gap between cards

**Request Card Components:**

**1. Header Row**
- Document icon + name
- Right side: Status badge

**2. Request ID**
- Format: "REQ-XXX"
- Secondary text color

**3. Status Badge**
- Ready: Green checkmark (✓)
- Processing: Orange hourglass (⏳)
- Pending: Gray timer (⏲)
- Right-aligned

**4. Date Information**
- "Submitted: Mar 10, 2024"
- "Est: Mar 13, 2024" (if processing)
- Small text, secondary color

**5. Action Button**
- For "Ready": "Download Document"
- For "Processing": Show "Est. completion"
- For "Pending": Show "Queued"

**Status Badge Colors:**
```
STATUS        COLOR       BADGE
──────────────────────────────────
Ready         Green       ✓ Ready
Processing    Orange/Amber ⏳ Processing
Pending       Gray        ⏲ Pending
Rejected      Red         ✗ Rejected
```

**Interactions:**
- Tap card → View details
- Tap "Download Document" → Download PDF
  - Opens in PDF viewer or file manager
  - Can share or save
- Swipe to delete (optional, with confirmation)

**No Requests State:**
- Show message: "No requests yet"
- Show button: "Create Request"
- Emoji: 📂

**Filters (Optional):**
- All requests (default)
- Pending
- Processing
- Ready
- Completed

**Document Download:**
- Filename format: "Dologon_[DocumentType]_[RequestID].pdf"
- Example: "Dologon_Barangay_Clearance_REQ001.pdf"

---

### SCREEN 15: SETTINGS
**Purpose:** User account & app settings
**Access:** From bottom navigation

**Layout:**
```
┌─────────────────────────────────┐
│ [Status Bar]                    │
├─────────────────────────────────┤
│                                 │
│  Settings                       │
│                                 │
│ ACCOUNT                         │
│ [👤 Profile Information]        │
│ [🔐 Change Password]            │
│                                 │
│ NOTIFICATIONS                   │
│ SMS Notifications      [Toggle] │
│ Email Notifications    [Toggle] │
│ Push Notifications     [Toggle] │
│                                 │
│ SUPPORT                         │
│ [❓ Help & FAQ]                 │
│ [📧 Contact Support]            │
│ [ℹ️ About App]                  │
│                                 │
│ PRIVACY                         │
│ [📄 Terms & Conditions]         │
│ [🔒 Privacy Policy]             │
│                                 │
│ [🚪 Logout]                    │
│                                 │
├─────────────────────────────────┤
│ 🏠 Home │ 📂 Requests │ ⚙️ Sett│
└─────────────────────────────────┘
```

**Settings Sections:**

**1. ACCOUNT**
- **Profile Information**
  - View/edit name, email, phone
  - View verification status
- **Change Password**
  - Current password
  - New password
  - Confirm password

**2. NOTIFICATIONS**
- **SMS Notifications** (Toggle)
  - Status updates
  - Document ready notifications
  - Default: On

- **Email Notifications** (Toggle)
  - Request confirmations
  - Status updates
  - Default: On

- **Push Notifications** (Toggle)
  - Real-time alerts
  - Default: On

**3. SUPPORT**
- **Help & FAQ**
  - Common questions
  - Troubleshooting
  - Links to documentation

- **Contact Support**
  - Support form
  - Email template
  - Phone number
  - Chat with support

- **About App**
  - App version
  - Build number
  - Release notes

**4. PRIVACY**
- **Terms & Conditions**
  - Full T&C document
  - Scrollable view
  - Accept/decline

- **Privacy Policy**
  - Data usage policy
  - Data retention
  - User rights

**5. Logout**
- **Logout Button**
  - Red button (danger color)
  - Confirmation dialog
  - "Are you sure? Your session will end."
  - Returns to login screen

**Interactions:**
- Tap menu item → Navigate to settings page
- Toggle notifications → Save preference immediately
- Logout → Confirmation → Clear session → Go to login

**Settings Persistence:**
- All settings saved to device
- Synced with backend
- Survives app close/restart

---

## User Flows

### FLOW 1: NEW USER REGISTRATION
```
Splash (1) 
  → Carousel (2) 
  → Sign Up (5) 
  → Face Recognition (6) 
  → Sign Up OTP (7) 
  → Step 1: Profile (8) 
  → Step 2: Education (9) 
  → Step 3: ID Check (10) 
  → Verification Waiting (11) 
  → Dashboard (12) [upon approval]
```

**Time to Complete:** 15-30 minutes

### FLOW 2: EXISTING USER LOGIN
```
Splash (1) 
  → Carousel (skip) (2) 
  → Login (3) 
  → Login OTP (4) 
  → Dashboard (12)
```

**Time to Complete:** 2-3 minutes

### FLOW 3: REQUEST DOCUMENT
```
Dashboard (12) 
  → Request Document (13) 
  → My Requests (14)
```

**Time to Complete:** 1-2 minutes

### FLOW 4: VIEW REQUESTS & DOWNLOAD
```
Dashboard (12) 
  → My Requests (14) 
  → Select Request 
  → Download Document
```

**Time to Complete:** 1 minute

---

## Form Specifications

### Validation Rules Summary

```
FIELD                   TYPE        MIN   MAX   VALIDATION
────────────────────────────────────────────────────────────
Username                Text        6     20    Alphanumeric+_
Email                   Email       -     -     Valid format
Phone (Contact)         Tel         11    13    +63 9xx format
Password                Password    8     -     4-types req'd
Age                     Number      18    120   Integer
Gender                  Dropdown    -     -     One of options
Address                 Text        10    200   Dologon only
Years at Address        Dropdown    -     -     One of options
Mother's Name           Text        2     100   Letters+spaces
Father's Name           Text        2     100   Letters+spaces
Education Level         Dropdown    -     -     One of options
School Name             Text        -     150   Text
Year Graduated          Number      1950  2035  YYYY
Course/Strand           Text        -     100   Text
Cert. File              File        -     5MB   PDF/JPG/PNG
ID Type                 Radio       -     -     Primary/Secondary
ID Document             Dropdown    -     -     One of options
ID Front Image          Image       -     5MB   JPG/PNG
ID Back Image           Image       -     5MB   JPG/PNG
Document Type           Radio       -     -     3 options
Request Purpose         Dropdown    -     -     6 options
Additional Details      Text        -     500   Text
Delivery Method         Radio       -     -     2 options
```

---

## Technical Specifications

### Device Requirements
- **OS:** Android 6.0 (API 23) minimum
- **Screen:** 4.5" - 6.7" (phones)
- **RAM:** 2GB minimum recommended
- **Storage:** 100MB free space
- **Camera:** Required for face recognition
- **Network:** Mobile data or WiFi

### Permissions Required
```
<uses-permission android:name="android.permission.CAMERA" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.RECEIVE_SMS" />
```

### API Integration Points
- User Authentication (REST)
- OTP Service (SMS/Email)
- Face Recognition Service
- File Upload Service
- Document Download Service
- Push Notification Service
- User Profile Service

### Libraries & Dependencies
```
// UI Framework
- AndroidX
- Material Design Components

// Networking
- Retrofit 2
- OkHttp 3
- Gson

// Image Processing
- Glide
- Picasso

// Face Recognition
- ML Kit (Google)
- AWS Rekognition (alternative)

// Local Storage
- Room Database
- SharedPreferences

// Notifications
- Firebase Cloud Messaging

// File Operations
- DocumentFile
- Content Providers
```

### Data Storage (Local)
- User credentials (encrypted)
- User profile info
- Last login timestamp
- App preferences
- Cached documents
- Submitted form data

---

## UI/UX Guidelines

### Color Palette
```
PRIMARY (Info Blue)      #378ADD
PRIMARY DARK             #185FA5
ACCENT (Success Green)   #639922
WARNING (Orange)         #BA7517
DANGER (Red)             #E24B4A
TEXT PRIMARY             #2C2C2A
TEXT SECONDARY           #5F5E5A
TEXT TERTIARY            #88877E
BACKGROUND PRIMARY       #FFFFFF
BACKGROUND SECONDARY     #F1EFE8
BACKGROUND TERTIARY      #D3D1C7
BORDER                   #B4B2A9
```

### Typography
```
ELEMENT          FONT-SIZE  WEIGHT  USAGE
─────────────────────────────────────────
Page Title       20px       500     Screen headings
Section Title    16px       500     Major sections
Subsection       13px       500     Labels, subheadings
Body Text        14px       400     Form fields, content
Small Text       12px       400     Hints, secondary info
Tiny Text        11px       400     Captions, timestamps
```

### Spacing
```
ELEMENT              VALUE
──────────────────────────────
Page padding         16px
Section margin       16px
Component margin     12px
Field spacing        12px
Line height (text)   1.5
Button padding       12px vertical, 16px horizontal
Icon size            24px (default)
```

### Component Sizes
```
COMPONENT           SIZE
────────────────────────────
Button              44px height (min touch target)
Input Field         44px height
Toggle Switch       24px × 48px
Checkbox            24px × 24px
Icon (large)        64px × 64px
Icon (medium)       40px × 40px
Icon (standard)     24px × 24px
Avatar Circle       40px diameter
Progress Indicator  28px circles
```

### Animation
```
ANIMATION        DURATION   EASING
──────────────────────────────────
Screen fade      200ms      EaseInOut
Button ripple    300ms      Linear
Loading spinner  800ms      Linear
Slide transition 300ms      EaseInOut
```

---

## Accessibility

### Text Alternatives
- All icons have text labels
- Images have descriptions
- Buttons have clear labels

### Touch Targets
- Minimum 44px × 44px
- 8px padding between targets

### Color Contrast
- WCAG AA compliant
- Text on background: 4.5:1 ratio
- Buttons: High contrast for visibility

### Font Size
- Minimum 12px
- Scalable text
- Respects device settings

---

## Testing Checklist

### Functional Testing
- [ ] User registration flow complete
- [ ] Login with OTP works
- [ ] Face recognition captures
- [ ] All form validations work
- [ ] File uploads process correctly
- [ ] Document requests submit
- [ ] Download functionality works

### UI/UX Testing
- [ ] All screens display correctly
- [ ] Proper spacing on all devices
- [ ] Text is readable
- [ ] Buttons are responsive
- [ ] Images load properly
- [ ] Animations are smooth

### Security Testing
- [ ] Password encryption works
- [ ] OTP codes are secure
- [ ] Data transmission is encrypted
- [ ] Session timeout works
- [ ] Logout clears data

### Performance Testing
- [ ] App loads in < 3 seconds
- [ ] Forms respond quickly
- [ ] File uploads complete
- [ ] Smooth scrolling
- [ ] Minimal memory usage

---

## Version History

**Version 1.0 - Initial Release**
- Complete user registration flow
- Face recognition integration
- OTP verification (SMS/Email)
- 3-step account verification
- Document request system
- Request tracking
- User settings

---

**Document Version:** 1.0
**Last Updated:** March 2024
**Status:** Ready for Development
