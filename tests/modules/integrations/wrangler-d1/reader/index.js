export default {
  async fetch(request, env) {
    const { count } = await env.DB.prepare("SELECT COUNT(*) AS count FROM notes").first();

    return Response.json({ count });
  },
};
