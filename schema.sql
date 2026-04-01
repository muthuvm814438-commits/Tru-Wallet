-- Enable UUID extension if needed
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 1. Balances Table
CREATE TABLE IF NOT EXISTS balances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    asset VARCHAR(50) NOT NULL,
    amount NUMERIC NOT NULL DEFAULT 0,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, asset)
);

-- RLS
ALTER TABLE balances ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own balances" ON balances
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 2. Withdrawals Table
CREATE TABLE IF NOT EXISTS withdrawals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    asset VARCHAR(50) NOT NULL,
    amount NUMERIC NOT NULL,
    destination_address VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS
ALTER TABLE withdrawals ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own withdrawals" ON withdrawals
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 3. Deposits Table
CREATE TABLE IF NOT EXISTS deposits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    asset VARCHAR(50) NOT NULL,
    amount NUMERIC NOT NULL,
    source_address VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Pending',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS
ALTER TABLE deposits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own deposits" ON deposits
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);

-- 4. External Wallets Table
CREATE TABLE IF NOT EXISTS external_wallets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    asset VARCHAR(50) NOT NULL,
    address VARCHAR(255) NOT NULL,
    status VARCHAR(50) NOT NULL DEFAULT 'Verified',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    UNIQUE(user_id, asset, address)
);

-- RLS
ALTER TABLE external_wallets ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own external wallets" ON external_wallets
    FOR ALL USING (auth.uid() = user_id) WITH CHECK (auth.uid() = user_id);
-- 5. Profiles Table
CREATE TABLE IF NOT EXISTS profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    avatar_url TEXT,
    phone VARCHAR(50),
    address TEXT,
    birthday DATE,
    country VARCHAR(100),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can manage their own profile" ON profiles
    FOR ALL USING (auth.uid() = id) WITH CHECK (auth.uid() = id);

-- 6. Trigger for Admin Balance Adjustments
-- This automatically creates a 'Deposit' record when an admin increases a balance
CREATE OR REPLACE FUNCTION handle_admin_balance_adjustment()
RETURNS TRIGGER AS $$
BEGIN
    -- Only record if amount is increased
    IF (TG_OP = 'INSERT') OR (NEW.amount > OLD.amount) THEN
        INSERT INTO deposits (user_id, asset, amount, source_address, status, created_at)
        VALUES (
            NEW.user_id, 
            NEW.asset, 
            CASE 
                WHEN TG_OP = 'INSERT' THEN NEW.amount 
                ELSE (NEW.amount - OLD.amount) 
            END, 
            'Admin Credit', 
            'Complete', 
            now()
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trig_admin_balance_adjustment ON balances;
CREATE TRIGGER trig_admin_balance_adjustment
AFTER INSERT OR UPDATE ON balances
FOR EACH ROW EXECUTE FUNCTION handle_admin_balance_adjustment();
