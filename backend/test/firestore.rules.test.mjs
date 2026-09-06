/**
 * Firestore rules tests — run with:
 *   cd backend && npx firebase emulators:exec --only firestore "node test/firestore.rules.test.mjs"
 */
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { readFileSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { doc, getDoc, setDoc, deleteDoc, updateDoc } from 'firebase/firestore';

const __dirname = dirname(fileURLToPath(import.meta.url));
const rules = readFileSync(resolve(__dirname, '../firestore.rules'), 'utf8');

const PROJECT_ID = 'masala-brother-test';

let testEnv;

before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: '127.0.0.1', port: 8085 },
  });
});

after(async () => {
  await testEnv?.cleanup();
});

beforeEach(async () => {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'households/main'), {
      memberEmails: ['roberto@example.com', 'laura@example.com'],
      members: {},
      enableAttachments: false,
    });
  });
});

function authed(email) {
  return testEnv.authenticatedContext('uid-' + email, { email }).firestore();
}

describe('households/main access', () => {
  it('allows Roberto to read household', async () => {
    const db = authed('roberto@example.com');
    await assertSucceeds(getDoc(doc(db, 'households/main')));
  });

  it('allows Laura to read household', async () => {
    const db = authed('laura@example.com');
    await assertSucceeds(getDoc(doc(db, 'households/main')));
  });

  it('denies outsider read', async () => {
    const db = authed('altro@gmail.com');
    await assertFails(getDoc(doc(db, 'households/main')));
  });

  it('denies unauthenticated read', async () => {
    const db = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'households/main')));
  });

  it('allows member to create expense; denies hard delete', async () => {
    const db = authed('roberto@example.com');
    const ref = doc(db, 'households/main/expenses/e1');
    await assertSucceeds(
      setDoc(ref, {
        description: 'Bolletta',
        amountDueCents: 1000,
        deletedAt: null,
      }),
    );
    await assertSucceeds(updateDoc(ref, { deletedAt: new Date().toISOString() }));
    await assertFails(deleteDoc(ref));
  });

  it('allows member to create transfer; denies hard delete', async () => {
    const db = authed('laura@example.com');
    const ref = doc(db, 'households/main/transfers/t1');
    await assertSucceeds(
      setDoc(ref, {
        fromUid: 'uid-laura@example.com',
        toUid: 'uid-roberto@example.com',
        amountCents: 438650,
        deletedAt: null,
      }),
    );
    await assertSucceeds(updateDoc(ref, { deletedAt: new Date().toISOString() }));
    await assertFails(deleteDoc(ref));
  });

  it('allows personal task list owned by self; denies owning as the other', async () => {
    const rob = authed('roberto@example.com');
    await assertSucceeds(
      setDoc(doc(rob, 'households/main/taskLists/campagna'), {
        name: 'Campagna',
        ownerUid: 'uid-roberto@example.com',
        deletedAt: null,
      }),
    );
    await assertFails(
      setDoc(doc(rob, 'households/main/taskLists/laura-only'), {
        name: 'No',
        ownerUid: 'uid-laura@example.com',
        deletedAt: null,
      }),
    );
    await assertSucceeds(
      setDoc(doc(rob, 'households/main/tasks/t1'), {
        title: 'Comprare la terra',
        listId: 'campagna',
        listOwnerUid: 'uid-roberto@example.com',
        deletedAt: null,
      }),
    );
  });
});
