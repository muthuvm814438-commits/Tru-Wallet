/**
 * user-profile.js
 * Centralized script to handle user session, profile loading, and UI synchronization
 * (Sidebar and Header Avatars/Names)
 */

window.loadUserProfile = async function() {
    let retries = 0;
    while (!window.insforgeClient && retries < 50) {
        await new Promise(r => setTimeout(r, 50));
        retries++;
    }

    if (!window.insforgeClient) {
        console.error("InsForge Client not found.");
        return;
    }

    try {
        console.log("Syncing profile data...");
        const { data, error } = await window.insforgeClient.auth.getCurrentUser();
        const user = data?.user || data;

        if (error || !user) {
            console.log("No active session.");
            if (!window.location.href.includes('index.html')) {
                window.location.href = 'index.html';
            }
            return;
        }

        const userIdShort = user.id.split('-')[0].toUpperCase();
        const email = user.email || "";

        // Fetch profile from database
        const { data: profile, error: profError } = await window.insforgeClient.database
            .from('profiles')
            .select('*')
            .eq('id', user.id)
            .single();

        const defaultAvatar = "https://tru-wallet.net/images/avt/avt.png";
        
        // Final Avatar URL logic
        let avatarUrl = defaultAvatar;
        let fullName = email.split('@')[0];

        if (profile) {
            fullName = `${profile.first_name || ''} ${profile.last_name || ''}`.trim() || fullName;
            
            // Check if avatar_url is poisoned or missing
            const dbAvatar = profile.avatar_url;
            if (dbAvatar && typeof dbAvatar === 'string' && dbAvatar !== '[object Object]' && dbAvatar.startsWith('http')) {
                avatarUrl = dbAvatar;
            } else if (dbAvatar && typeof dbAvatar === 'object' && dbAvatar.publicUrl) {
                avatarUrl = dbAvatar.publicUrl;
            }
            console.log("Avatar URL identified:", avatarUrl);
        }

        // Apply changes to UI
        $('#header-avatar').attr('src', avatarUrl);
        $('#sidebar-avatar').attr('src', avatarUrl);
        $('#user-avatar').attr('src', avatarUrl);
        $('#sidebar-avatar-large').attr('src', avatarUrl); // Some pages might use this
        
        const nameDisplay = `${fullName} (${userIdShort})`;
        $('#sidebar-name').text(nameDisplay);
        $('#user-display-name').text(nameDisplay);
        $('#user-display-name-sidebar').text(nameDisplay);
        $('#sidebar-email').text(email);
        $('#user-display-email').text(email);

    } catch (e) {
        console.warn("Profile sync error:", e);
    }
};

window.handleLogout = async function() {
    if (window.insforgeClient) {
        await window.insforgeClient.auth.signOut();
    }
    window.location.href = 'index.html';
};

// Auto-run on load
$(document).ready(() => {
    window.loadUserProfile();
});
