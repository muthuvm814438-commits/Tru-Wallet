import { createClient } from "./node_modules/@insforge/sdk/dist/index.mjs";

const insforge = createClient({ 
    baseUrl: 'https://4zz6pu22.us-east.insforge.app', 
    anonKey: 'ik_1c22ac3aa09b965ab82493f7a5280877' 
});

async function run() {
    // try signing in
    const email = "test@example.com";
    const password = "password123";

    let res = await insforge.auth.signInWithPassword({ email, password });
    if (res.error) {
        // try sign up
        res = await insforge.auth.signUp({ email, password });
        console.log("Registered", res.data);
    } else {
        console.log("Logged in", res.data);
    }

    const { data: user } = await insforge.auth.getCurrentUser();
    console.log("User:", user);

    const payload = {
        user_id: user?.id,
        amount: 50,
        status: 'Pending',
        asset: 'USDT',
        destination_address: '0xTestAddress'
    };
    
    console.log("Inserting payload", payload);
    const result = await insforge.database.from('withdrawals').insert(payload);
    console.log("Insert result", result);

    const result2 = await insforge.database.from('withdrawals').insert([payload]);
    console.log("Array Insert result", result2);
}

run();
