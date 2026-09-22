import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const jsonHeaders = {
  "Content-Type": "application/json",
};

Deno.serve(async (request) => {
  if (request.method !== "POST") {
    return new Response(JSON.stringify({ error: "method_not_allowed" }), {
      status: 405,
      headers: jsonHeaders,
    });
  }

  const authorization = request.headers.get("Authorization");
  if (!authorization?.startsWith("Bearer ")) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  const url = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const revenueCatSecretApiKey = Deno.env.get("REVENUECAT_SECRET_API_KEY");
  if (!url || !serviceRoleKey || !revenueCatSecretApiKey) {
    return new Response(JSON.stringify({ error: "server_not_configured" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  const admin = createClient(url, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const token = authorization.slice("Bearer ".length);
  const { data, error: userError } = await admin.auth.getUser(token);
  if (userError || !data.user) {
    return new Response(JSON.stringify({ error: "unauthorized" }), {
      status: 401,
      headers: jsonHeaders,
    });
  }

  // The Supabase UUID is also the RevenueCat App User ID. Remove purchase
  // profile data before deleting the identity needed to retry this operation.
  // This does not cancel an App Store subscription; cancellation remains a
  // store-managed action that the app explains separately.
  const revenueCatResponse = await fetch(
    `https://api.revenuecat.com/v1/subscribers/${
      encodeURIComponent(data.user.id)
    }`,
    {
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${revenueCatSecretApiKey}`,
        "Content-Type": "application/json",
      },
    },
  );
  if (!revenueCatResponse.ok && revenueCatResponse.status !== 404) {
    return new Response(
      JSON.stringify({ error: "purchase_profile_delete_failed" }),
      { status: 502, headers: jsonHeaders },
    );
  }

  const { error: deleteError } = await admin.auth.admin.deleteUser(
    data.user.id,
  );
  if (deleteError) {
    return new Response(JSON.stringify({ error: "delete_failed" }), {
      status: 500,
      headers: jsonHeaders,
    });
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200,
    headers: jsonHeaders,
  });
});
