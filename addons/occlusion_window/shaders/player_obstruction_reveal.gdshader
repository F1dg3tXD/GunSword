shader_type spatial;

render_mode
    unshaded,
    fog_disabled,
    cull_disabled,
    depth_test_disabled,
    depth_draw_never,
    blend_mix;


// The clean version of the scene.
uniform sampler2D clean_scene_texture : source_color, filter_linear;


// Main viewport depth.
uniform sampler2D depth_texture : hint_depth_texture, filter_nearest;


// Player position in camera/view space.
uniform float player_view_depth;


// Player position on screen, in 0..1 UV coordinates.
uniform vec2 player_screen_uv;


// Radius of the hole around the player.
uniform float reveal_radius = 0.08;


// Softness of the hole edge.
uniform float reveal_softness = 0.03;


// How much closer an obstruction must be
// than the player before it is considered blocking.
uniform float depth_epsilon = 0.05;


// Overall effect opacity.
uniform float reveal_opacity = 1.0;


// ------------------------------------------------------------
// Fullscreen quad
// ------------------------------------------------------------

void vertex()
{
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}


// ------------------------------------------------------------
// Convert depth buffer → view-space depth
// ------------------------------------------------------------

float get_linear_depth(vec2 uv)
{
    float depth =
        texture(
            depth_texture,
            uv
        ).r;


    #if CURRENT_RENDERER == RENDERER_COMPATIBILITY

        vec3 ndc =
            vec3(
                uv,
                depth
            ) * 2.0 - 1.0;

    #else

        vec3 ndc =
            vec3(
                uv * 2.0 - 1.0,
                depth
            );

    #endif


    vec4 view =
        INV_PROJECTION_MATRIX *
        vec4(
            ndc,
            1.0
        );


    view.xyz /= view.w;


    // Camera looks down -Z.
    return -view.z;
}


// ------------------------------------------------------------
// Fragment
// ------------------------------------------------------------

void fragment()
{
    float scene_depth =
        get_linear_depth(
            SCREEN_UV
        );


    /*
     * If the visible geometry is farther away than
     * the player, then it cannot be blocking the player.
     */

    bool player_is_behind_geometry =
        scene_depth <
        player_view_depth - depth_epsilon;


    if (!player_is_behind_geometry)
    {
        discard;
    }


    /*
     * Calculate distance from this screen pixel
     * to the player's screen position.
     */

    vec2 offset =
        SCREEN_UV -
        player_screen_uv;


    /*
     * Correct for aspect ratio so the hole remains
     * circular rather than becoming elliptical.
     */

    float aspect =
        VIEWPORT_SIZE.x /
        VIEWPORT_SIZE.y;

    offset.x *= aspect;


    float distance_from_player =
        length(offset);


    /*
     * Create the hole.
     */

    float hole =
        1.0 -
        smoothstep(
            reveal_radius,
            reveal_radius + reveal_softness,
            distance_from_player
        );


    hole *= reveal_opacity;


    if (hole <= 0.001)
    {
        discard;
    }


    /*
     * Pull the corresponding pixel from the clean
     * version of the scene.
     */

    vec4 clean_color =
        texture(
            clean_scene_texture,
            SCREEN_UV
        );


    ALBEDO =
        clean_color.rgb;

    EMISSION =
        clean_color.rgb;

    ALPHA =
        clean_color.a * hole;
}