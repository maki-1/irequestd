/**
 * Seed script — inserts residents directly into MongoDB as fully-verified accounts.
 * Run: node seed_users.js
 */
require('dotenv').config();
const mongoose = require('mongoose');
const User = require('./models/User');
const VerificationProfile = require('./models/VerificationProfile');

const DEFAULT_PASSWORD = 'Dologon@2025';

// fullName format: "Lastname, Firstname MI." → stored as "Firstname MI. Lastname"
function naturalName(raw) {
  const [last, rest] = raw.split(', ');
  return `${rest} ${last}`.trim();
}

function makeUsername(raw) {
  const [last, rest] = raw.split(', ');
  const firstName = (rest || '').split(' ')[0].replace(/[^a-zA-Z]/g, '').toLowerCase();
  const lastName  = last.replace(/[^a-zA-Z]/g, '').toLowerCase();
  return `${firstName}.${lastName}`;
}

const residents = [
  { raw: 'Alivio, Fhevie L.',          gender: 'Female', age: 21, purok: 'Purok 9',  father: 'Kevin Alivio',     mother: 'Julieta Alivio',     edu: 'High School',         school: 'Dologon National High School', grad: '2021', years: '2',  pwd: false },
  { raw: 'Arota, Jaspher S.',           gender: 'Male',   age: 19, purok: 'Purok 17', father: 'Joshua Arota',     mother: 'Bridget Arota',      edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2021', years: '14', pwd: true  },
  { raw: 'Arquillos, Reymond R.',       gender: 'Male',   age: 19, purok: 'Purok 3',  father: 'John Arquillos',   mother: 'Mae Arquillos',      edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '7',  pwd: false },
  { raw: 'Batoon, Geraldine A.',        gender: 'Female', age: 24, purok: 'Purok 10', father: 'Paul Batoon',      mother: 'Bridget Batoon',     edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '10', pwd: false },
  { raw: 'Beralde, Ryse Ian Prince B.', gender: 'Female', age: 20, purok: 'Purok 2',  father: 'Romy Beralde',     mother: 'Miralyn Beralde',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '11', pwd: true  },
  { raw: 'Bonghanoy, Ivonie B.',        gender: 'Female', age: 25, purok: 'Purok 6',  father: 'Mark Bonghanoy',   mother: 'Joy Bonghanoy',      edu: 'High School',         school: 'Dologon National High School', grad: '2023', years: '15', pwd: false },
  { raw: 'Ceballos, Mark June E.',      gender: 'Male',   age: 21, purok: 'Purok 3',  father: 'Carl Ceballos',    mother: 'Angelica Ceballos',  edu: 'High School',         school: 'Dologon National High School', grad: '2023', years: '17', pwd: false },
  { raw: 'Cimeni, Carlo B.',            gender: 'Male',   age: 25, purok: 'Purok 11', father: 'Paul Cimeni',      mother: 'Princess Cimeni',    edu: 'High School',         school: 'Dologon National High School', grad: '2024', years: '12', pwd: true  },
  { raw: 'Comonlay, Carla Jean',        gender: 'Female', age: 19, purok: 'Purok 11', father: 'Paul Comonlay',    mother: 'Mae Comonlay',       edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2022', years: '17', pwd: false },
  { raw: 'Dalayon, Earl Jayson',        gender: 'Male',   age: 23, purok: 'Purok 16', father: 'Mark Dalayon',     mother: 'Anne Dalayon',       edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '11', pwd: true  },
  { raw: 'Demapiles, Zhynn Melchor',    gender: 'Male',   age: 20, purok: 'Purok 18', father: 'John Demapiles',   mother: 'Rosalie Demapiles',  edu: 'Senior High School',  school: 'Dologon National High School', grad: '2021', years: '16', pwd: true  },
  { raw: 'Dy, Danniel Justine V.',      gender: 'Male',   age: 23, purok: 'Purok 9',  father: 'John Dy',          mother: 'Princess Dy',        edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '20', pwd: false },
  { raw: 'Eliseo, Kate Ellah B.',       gender: 'Female', age: 21, purok: 'Purok 14', father: 'Joshua Eliseo',    mother: 'Anne Eliseo',        edu: 'Senior High School',  school: 'Dologon National High School', grad: '2022', years: '14', pwd: true  },
  { raw: 'Encinas, Mc Kingly S.',       gender: 'Male',   age: 21, purok: 'Purok 9',  father: 'John Encinas',     mother: 'Joy Encinas',        edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '6',  pwd: false },
  { raw: 'Gaburno, Jc Vincent T.',      gender: 'Male',   age: 23, purok: 'Purok 17', father: 'Joshua Gaburno',   mother: 'Angelica Gaburno',   edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2021', years: '17', pwd: true  },
  { raw: 'Gallardo, Irha Mae A.',       gender: 'Female', age: 23, purok: 'Purok 4',  father: 'Jomar Gallardo',   mother: 'Christine Gallardo', edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '20', pwd: false },
  { raw: 'Garcia, Lawrence John I.',    gender: 'Male',   age: 18, purok: 'Purok 17', father: 'Alexander Garcia', mother: 'Rosalie Garcia',     edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2021', years: '6',  pwd: true  },
  { raw: 'Gerochi, Mc Jiynbern S.',     gender: 'Male',   age: 21, purok: 'Purok 11', father: 'Mark Gerochi',     mother: 'Jineffer Gerochi',   edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2021', years: '1',  pwd: true  },
  { raw: 'Jungco, Recson Clinth P.',    gender: 'Male',   age: 26, purok: 'Purok 8',  father: 'John Jungco',      mother: 'Angelica Jungco',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '7',  pwd: false },
  { raw: 'Lusing, Rosalie G.',          gender: 'Female', age: 26, purok: 'Purok 7',  father: 'Paul Lusing',      mother: 'Mae Lusing',         edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2022', years: '18', pwd: true  },
  { raw: 'Madar, Jackilou A.',          gender: 'Female', age: 21, purok: 'Purok 6',  father: 'Joshua Madar',     mother: 'Princess Madar',     edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '4',  pwd: true  },
  { raw: 'Morales, Angeline P.',        gender: 'Female', age: 25, purok: 'Purok 18', father: 'Paul Morales',     mother: 'Bridget Morales',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '18', pwd: false },
  { raw: 'Narvasa, Darryl John',        gender: 'Male',   age: 24, purok: 'Purok 5',  father: 'Joshua Narvasa',   mother: 'Princess Narvasa',   edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '1',  pwd: false },
  { raw: 'Obar, Johanah Mae A.',        gender: 'Female', age: 19, purok: 'Purok 15', father: 'Alexander Obar',   mother: 'Angelica Obar',      edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '20', pwd: false },
  { raw: 'Oppus, Lelanie Joy S.',       gender: 'Female', age: 18, purok: 'Purok 9',  father: 'Jomar Oppus',      mother: 'Bridget Oppus',      edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2024', years: '11', pwd: true  },
  { raw: 'Ortiz, Alexander L.',         gender: 'Male',   age: 24, purok: 'Purok 20', father: 'Mark Ortiz',       mother: 'Joy Ortiz',          edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2024', years: '4',  pwd: false },
  { raw: 'Pasayon, Bridget Myles C.',   gender: 'Female', age: 24, purok: 'Purok 2',  father: 'Carl Pasayon',     mother: 'Bridget Pasayon',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '20', pwd: false },
  { raw: 'Pascual, Vincent F.',         gender: 'Male',   age: 22, purok: 'Purok 7',  father: 'Alexander Pascual',mother: 'Princess Pascual',   edu: 'Senior High School',  school: 'Dologon National High School', grad: '2024', years: '8',  pwd: true  },
  { raw: 'Pedrosa, Rhealene Apple',     gender: 'Female', age: 26, purok: 'Purok 21', father: 'Jomar Pedrosa',    mother: 'Rosalie Pedrosa',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2023', years: '6',  pwd: false },
  { raw: 'Salinas, Girlyn',             gender: 'Female', age: 24, purok: 'Purok 7',  father: 'Jomar Salinas',    mother: 'Mae Salinas',        edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2021', years: '18', pwd: false },
  { raw: 'Santiago, Fritz Joshua',      gender: 'Male',   age: 21, purok: 'Purok 4',  father: 'Vincent Santiago', mother: 'Christine Santiago', edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2024', years: '1',  pwd: false },
  { raw: 'Tac-an, Darlene S.',          gender: 'Female', age: 26, purok: 'Purok 14', father: 'Paul Tac-an',      mother: 'Angelica Tac-an',    edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '6',  pwd: true  },
  { raw: 'Taghap, Gerald B.',           gender: 'Male',   age: 20, purok: 'Purok 14', father: 'Jomar Taghap',     mother: 'Rosalie Taghap',     edu: 'High School',         school: 'Dologon National High School', grad: '2023', years: '13', pwd: true  },
  { raw: 'Tavita, Sherlyn Bhel M.',     gender: 'Female', age: 23, purok: 'Purok 6',  father: 'Joshua Tavita',    mother: 'Joy Tavita',         edu: 'Senior High School',  school: 'Maramag National High School', grad: '2022', years: '17', pwd: false },
  { raw: 'Trabuco, Karl Christian E.',  gender: 'Male',   age: 22, purok: 'Purok 20', father: 'Rene Trabuco',     mother: 'Maria Fe Evangelio', edu: 'Senior High School',  school: 'Dologon National High School', grad: '2024', years: '5',  pwd: true  },
  { raw: 'Yanson, Jezreel Gem S.',      gender: 'Male',   age: 25, purok: 'Purok 18', father: 'Carl Yanson',      mother: 'Christine Yanson',   edu: 'Senior High School',  school: 'Maramag National High School', grad: '2023', years: '19', pwd: true  },
  { raw: 'Madjos, Mechelle',            gender: 'Female', age: 25, purok: 'Purok 15', father: 'Mark Madjos',      mother: 'Anne Madjos',        edu: 'Senior High School',  school: 'Maramag National High School', grad: '2023', years: '16', pwd: true  },
  { raw: 'Escabarte, John Lloyd',       gender: 'Male',   age: 24, purok: 'Purok 19', father: 'Paul Escabarte',   mother: 'Princess Escabarte', edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '19', pwd: true  },
  { raw: 'Abellanosa, Krisha Mae',      gender: 'Female', age: 25, purok: 'Purok 15', father: 'Vincent Abellanosa',mother:'Mae Abellanosa',     edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '12', pwd: true  },
  { raw: 'Bacus, John Rey',             gender: 'Male',   age: 18, purok: 'Purok 10', father: 'Paul Bacus',       mother: 'Anne Bacus',         edu: 'Senior High School',  school: 'Dologon National High School', grad: '2023', years: '3',  pwd: false },
  { raw: 'Cortez, Mariel P.',           gender: 'Female', age: 25, purok: 'Purok 15', father: 'Carl Cortez',      mother: 'Bridget Cortez',     edu: 'Senior High School',  school: 'Dologon National High School', grad: '2023', years: '18', pwd: true  },
  { raw: 'Dela Cruz, Kevin M.',         gender: 'Male',   age: 22, purok: 'Purok 15', father: 'Carl Dela Cruz',   mother: 'Joy Dela Cruz',      edu: 'Senior High School',  school: 'Dologon National High School', grad: '2022', years: '10', pwd: false },
  { raw: 'Fernandez, Lovely Anne',      gender: 'Female', age: 18, purok: 'Purok 13', father: 'Joshua Fernandez', mother: 'Christine Fernandez',edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2023', years: '4',  pwd: false },
  { raw: 'Guinto, Jomar T.',            gender: 'Male',   age: 23, purok: 'Purok 3',  father: 'Alexander Guinto', mother: 'Bridget Guinto',     edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2023', years: '19', pwd: true  },
  { raw: 'Hernandez, Angelica V.',      gender: 'Female', age: 21, purok: 'Purok 20', father: 'John Hernandez',   mother: 'Anne Hernandez',     edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2023', years: '18', pwd: false },
  { raw: 'Ignacio, Paul Lester',        gender: 'Male',   age: 25, purok: 'Purok 3',  father: 'Carl Ignacio',     mother: 'Angelica Ignacio',   edu: 'Senior High School',  school: 'Dologon National High School', grad: '2023', years: '18', pwd: false },
  { raw: 'Labrador, Christine Joy',     gender: 'Female', age: 19, purok: 'Purok 16', father: 'Kevin Labrador',   mother: 'Angelica Labrador',  edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2022', years: '16', pwd: false },
  { raw: 'Mendoza, Carl Adrian',        gender: 'Male',   age: 25, purok: 'Purok 2',  father: 'Kevin Mendoza',    mother: 'Bridget Mendoza',    edu: 'Senior High School',  school: 'Maramag National High School', grad: '2021', years: '9',  pwd: false },
  { raw: 'Neri, Princess Mae',          gender: 'Female', age: 21, purok: 'Purok 21', father: 'Carl Neri',        mother: 'Angelica Neri',      edu: 'College Graduate',    school: 'Central Mindanao University',  grad: '2024', years: '7',  pwd: false },
  { raw: 'Villanueva, Joshua Kim',      gender: 'Male',   age: 23, purok: 'Purok 2',  father: 'Vincent Villanueva',mother:'Bridget Villanueva', edu: 'Senior High School',  school: 'Central Mindanao University',  grad: '2023', years: '17', pwd: false },
];

async function seed() {
  await mongoose.connect(process.env.MONGO_URI);
  console.log('Connected to MongoDB\n');

  const usernameCount = {};
  const credentials = [];
  const now = new Date();

  for (let i = 0; i < residents.length; i++) {
    const r = residents[i];

    let base = makeUsername(r.raw);
    usernameCount[base] = (usernameCount[base] || 0) + 1;
    const username = usernameCount[base] > 1 ? `${base}${usernameCount[base]}` : base;

    const contactNumber = `091${String(i + 1).padStart(8, '0')}`;

    try {
      const user = await User.create({
        username,
        contactNumber,
        email: '',
        password: DEFAULT_PASSWORD, // pre-save hook hashes this
        isVerified: true,
      });

      await VerificationProfile.create({
        user:           user._id,
        fullName:       naturalName(r.raw),
        address:        `${r.purok}, Brgy. Dologon, Maramag, Bukidnon`,
        age:            r.age,
        gender:         r.gender,
        yearsAtAddress: r.years,
        motherName:     r.mother,
        fatherName:     r.father,
        isPwd:          r.pwd,
        educationLevel: r.edu,
        school:         r.school,
        yearGraduated:  r.grad,
        currentStep:    4,
        status:         'approved',
        submittedAt:    now,
        reviewedAt:     now,
      });

      credentials.push({ name: naturalName(r.raw), username, password: DEFAULT_PASSWORD });
      process.stdout.write(`✓ ${username}\n`);
    } catch (err) {
      process.stdout.write(`✗ ${username} — ${err.message}\n`);
    }
  }

  console.log('\n========== CREDENTIALS ==========');
  console.log(`${'NAME'.padEnd(35)} ${'USERNAME'.padEnd(25)} PASSWORD`);
  console.log('-'.repeat(75));
  credentials.forEach(c => {
    console.log(`${c.name.padEnd(35)} ${c.username.padEnd(25)} ${c.password}`);
  });
  console.log('=================================\n');
  console.log(`Inserted ${credentials.length} / ${residents.length} accounts.`);

  await mongoose.disconnect();
}

seed().catch(err => { console.error(err); process.exit(1); });
