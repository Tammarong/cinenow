// Security-rule tests for CineNow's Realtime Database.
//
//   1. firebase emulators:start --only auth,database   (from the project root)
//   2. cd tool/rules_test && npm install && npm test
//
// Uses its own database namespace, so app data in the emulator is untouched.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import { assertFails, assertSucceeds, initializeTestEnvironment } from '@firebase/rules-unit-testing';
import firebase from 'firebase/compat/app';
import 'firebase/compat/database';

const TS = firebase.database.ServerValue.TIMESTAMP;
const SHOW = 'cn-siam_dune-part-two_20261010_1820';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-cinenow-rules',
    database: {
      host: '127.0.0.1',
      port: 9000,
      rules: readFileSync(new URL('../../firebase/database.rules.json', import.meta.url), 'utf8'),
    },
  });
});

after(() => env?.cleanup());

beforeEach(async () => {
  await env.clearDatabase();
  await env.withSecurityRulesDisabled((ctx) =>
    ctx.database().ref().set({
      movies: { 'dune-part-two': { title: 'Dune: Part Two' } },
      showtimes: { 'dune-part-two': { [SHOW]: { date: '2026-10-10', time: '18:20' } } },
      occupiedSeats: { [SHOW]: { A1: { uid: 'box-office' } } },
    }),
  );
});

const db = (uid) => (uid ? env.authenticatedContext(uid).database() : env.unauthenticatedContext().database());

/** Reads a path as an admin (withSecurityRulesDisabled doesn't return values). */
async function adminGet(path) {
  let value;
  await env.withSecurityRulesDisabled(async (ctx) => {
    value = (await ctx.database().ref(path).get()).val();
  });
  return value;
}

/** The exact multi-path update the app sends on "Confirm Reservation". */
function booking(uid, resId, seats, { showtimeId = SHOW, reservationSeats = seats, bookedAt = TS } = {}) {
  const updates = {
    [`reservations/${uid}/${resId}`]: {
      ref: 'CN-TEST01',
      movieId: 'dune-part-two',
      movieTitle: 'Dune: Part Two',
      cinemaId: 'cn-siam',
      cinemaName: 'CineNow Siam Square',
      showtimeId,
      startsAt: 1791631200000,
      seats: Object.fromEntries(reservationSeats.map((s) => [s, true])),
      total: 790,
      createdAt: TS,
    },
  };
  for (const s of seats) updates[`occupiedSeats/${showtimeId}/${s}`] = { uid, reservationId: resId, bookedAt };
  return updates;
}

describe('catalog', () => {
  test('anyone can read movies and showtimes', async () => {
    await assertSucceeds(db(null).ref('movies').get());
    await assertSucceeds(db(null).ref(`showtimes/dune-part-two`).get());
    await assertSucceeds(db(null).ref(`occupiedSeats/${SHOW}`).get());
  });

  test('nobody can edit the catalog', async () => {
    await assertFails(db(null).ref('movies/x').set({ title: 'Hack' }));
    await assertFails(db('alice').ref('movies/dune-part-two/title').set('Hacked'));
    await assertFails(db('alice').ref(`showtimes/dune-part-two/${SHOW}/time`).set('00:00'));
  });
});

describe('profiles', () => {
  const profile = { displayName: 'Alice', email: 'alice@cinenow.test', createdAt: TS, city: 'Bangkok' };

  test('users can create and read only their own profile', async () => {
    await assertSucceeds(db('alice').ref('users/alice').set(profile));
    await assertSucceeds(db('alice').ref('users/alice').get());
    await assertFails(db('bob').ref('users/alice').get());
    await assertFails(db('bob').ref('users/alice/displayName').set('Bob'));
    await assertFails(db(null).ref('users/alice').get());
  });

  test('profiles reject unknown fields', async () => {
    await assertFails(db('alice').ref('users/alice').set({ ...profile, isAdmin: true }));
  });
});

describe('reservations & seats', () => {
  test('a signed-in user books seats atomically', async () => {
    await assertSucceeds(db('alice').ref().update(booking('alice', 'r1', ['E7', 'E8'])));
    const seat = await adminGet(`occupiedSeats/${SHOW}/E7`);
    if (seat?.uid !== 'alice' || seat?.reservationId !== 'r1') throw new Error('seat not stored');
    const res = await adminGet('reservations/alice/r1');
    if (!res?.seats?.E7 || !res?.seats?.E8) throw new Error('reservation not stored');
  });

  test('guests cannot book', async () => {
    await assertFails(db(null).ref().update(booking('anon', 'r1', ['E7'])));
  });

  test('double-booking is rejected and nothing is written', async () => {
    await assertSucceeds(db('alice').ref().update(booking('alice', 'r1', ['E7', 'E8'])));
    // Bob wants E8 (taken) and E9 (free): the whole update must fail.
    await assertFails(db('bob').ref().update(booking('bob', 'r2', ['E8', 'E9'])));
    if ((await adminGet(`occupiedSeats/${SHOW}/E9`)) !== null) throw new Error('E9 leaked through');
    if ((await adminGet('reservations/bob/r2')) !== null) throw new Error("Bob's reservation leaked through");
    if ((await adminGet(`occupiedSeats/${SHOW}/E8`))?.uid !== 'alice') throw new Error('E8 changed owner');
  });

  test('box-office seats cannot be taken', async () => {
    await assertFails(db('alice').ref().update(booking('alice', 'r1', ['A1'])));
  });

  test('a seat cannot be claimed without a matching reservation in the same write', async () => {
    await assertFails(
      db('alice').ref(`occupiedSeats/${SHOW}/E7`).set({ uid: 'alice', reservationId: 'ghost', bookedAt: TS }),
    );
    // Reservation that doesn't list the seat being claimed.
    await assertFails(db('alice').ref().update(booking('alice', 'r1', ['E7'], { reservationSeats: ['E6'] })));
  });

  test('seats cannot be claimed for someone else or with a fake timestamp', async () => {
    const forBob = booking('alice', 'r1', ['E7']);
    forBob[`occupiedSeats/${SHOW}/E7`].uid = 'bob';
    await assertFails(db('alice').ref().update(forBob));
    await assertFails(db('alice').ref().update(booking('alice', 'r1', ['E7'], { bookedAt: 1 })));
  });

  test('invalid seat ids are rejected', async () => {
    await assertFails(db('alice').ref().update(booking('alice', 'r1', ['Z99'])));
  });

  test('booked seats can never be released or reassigned by clients', async () => {
    await assertSucceeds(db('alice').ref().update(booking('alice', 'r1', ['E7'])));
    await assertFails(db('alice').ref(`occupiedSeats/${SHOW}/E7`).remove());
    await assertFails(db('bob').ref(`occupiedSeats/${SHOW}/E7`).remove());
    await assertFails(db('alice').ref(`occupiedSeats/${SHOW}`).remove());
    await assertFails(db('alice').ref(`occupiedSeats/${SHOW}/E7/uid`).set('bob'));
  });

  test('reservations are private and write-once', async () => {
    await assertSucceeds(db('alice').ref().update(booking('alice', 'r1', ['E7'])));
    await assertSucceeds(db('alice').ref('reservations/alice').get());
    await assertFails(db('bob').ref('reservations/alice').get());
    await assertFails(db('bob').ref('reservations/alice/r9').set(booking('alice', 'r9', [])['reservations/alice/r9']));
    await assertFails(db('alice').ref('reservations/alice/r1/total').set(0));
    await assertFails(db('alice').ref('reservations/alice/r1').remove());
  });
});
