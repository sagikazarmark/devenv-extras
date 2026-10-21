export default {
  async fetch(request, env) {
    const { count } = await env.DB.prepare("SELECT COUNT(*) AS count FROM notes").first();

    return Response.json({
      greeting: env.GREETING ?? null,
      self: env.SELF_URL ?? null,
      count,
    });
  },
};
