// =============================================================
//  VentFlap — one-way backdraft flap insert for a 100 mm duct
// =============================================================
//
//  Two printed parts + one pin (a piece of 1.75 mm filament):
//    body : sleeve that friction-fits inside the duct, with a mesh plate
//           at the room end and hinge knuckles on the outlet side
//    flap : disc that hangs from the hinge and seats against the mesh
//
//  Install: mesh plate faces the ROOM, sleeve/flap faces OUTSIDE,
//           hinge at the TOP. Air from the room pushes the flap open;
//           wind/backdraft pushes it shut against the mesh; gravity
//           holds it closed when there's no flow.
//
//  Print orientation is exactly as exported (no supports needed):
//    body : mesh plate on the bed, sleeve growing upward
//    flap : flat side on the bed, knuckles up
//
//  Render one part at a time:  part = "body" | "flap" | "assembly"
// -------------------------------------------------------------

part = "assembly";
open_angle = 0;          // assembly preview only: flap opening in degrees

/* ---------- Duct fit ---------- */
duct_id        = 100;    // measured INSIDE diameter of your duct
fit_clearance  = 0.6;    // diametral gap between sleeve and duct
rib_height     = 0.7;    // crush ribs on the outside (0 = none)
rib_count      = 12;

/* ---------- Body ---------- */
sleeve_len     = 25;     // total depth of the insert (your 20-30 mm)
sleeve_wall    = 2.4;
plate_t        = 2.4;    // mesh plate thickness
flange_w       = 0;      // >0 adds a stop lip at the room end (e.g. 5)
flange_t       = 2;

/* ---------- Mesh ---------- */
mesh_cell      = 6;      // hex cell size across flats (smaller = more restrictive)
mesh_bar       = 1.2;    // bar width between cells
seal_overlap   = 3;      // solid ring the flap rests on, around the mesh
// Sloped seat: the seat ring rises toward the bottom by this much, so the
// closed flap leans past its natural hanging angle and gravity holds it shut.
// The hinge axis sits ~3.5 mm proud of the plate, so a hanging flap naturally
// tilts open ~3.7 deg (~5 mm at the bottom); the slope must exceed that.
seat_drop      = 8;      // mm of rise at the bottom edge of the flap (0 = flat)

/* ---------- Flap & hinge ---------- */
flap_t         = 1.6;
flap_gap       = 1.2;    // radial gap between flap and sleeve
knuckle_r      = 3.2;    // hinge barrel radius
knuckle_gap    = 0.5;    // axial gap between interleaved knuckles
hinge_half     = 24;     // hinge spans x = -hinge_half .. +hinge_half
pin_d_body     = 1.9;    // snug on a 1.75 mm filament pin
pin_d_flap     = 2.4;    // free-running
stop_angle     = 55;     // flap stop: max opening before tab hits sleeve
slot_y0        = 6;      // side slot band (Y range, up = +Y)
slot_y1        = 34;
slot_z0        = 2;      // slots start this far above the plate

$fn = 96;

/* ---------- Derived ---------- */
body_od  = duct_id - fit_clearance;
R_o      = body_od/2;
R_i      = R_o - sleeve_wall;
R_flap   = R_i - flap_gap;
h_a      = knuckle_r + 0.3;                 // axis height above plate top
z_a      = plate_t + h_a;
// axis as high as possible while the end knuckles stay inside the sleeve
y_a      = sqrt(R_i*R_i - hinge_half*hinge_half) - knuckle_r - 0.6;
R_mesh   = R_flap - seal_overlap;
y_mesh   = y_a - knuckle_r - seal_overlap;  // mesh stops below the hinge band
phi      = atan(seat_drop / (y_a + R_flap));  // closed-flap angle off the plate

// knuckle layout along X: B F B F B  (B = body, F = flap)
kw       = (2*hinge_half - 4*knuckle_gap) / 5;
function kx(i) = -hinge_half + i*(kw + knuckle_gap);   // start x of knuckle i
body_k   = [0, 2, 4];
flap_k   = [1, 3];

// stop tab height so the tab touches the sleeve wall at stop_angle
tab_t    = 2;
tab_xmax = max([for (i = flap_k) abs(kx(i)+0.8), for (i = flap_k) abs(kx(i)+kw-0.8)]);
y_wall   = sqrt(R_i*R_i - tab_xmax*tab_xmax);
tab_h    = (y_wall - y_a - (tab_t/2)*cos(stop_angle)) / sin(stop_angle);

echo(str("body OD ", body_od, "  sleeve ID ", 2*R_i, "  flap R ", R_flap,
         "  hinge axis y ", y_a, "  stop tab h ", tab_h, "  seat angle ", phi));

// rotate children about the hinge axis by a (positive = opening)
module about_hinge(a) translate([0, y_a, z_a]) rotate([-a, 0, 0]) translate([0, -y_a, -z_a]) children();

module mesh_region2d() intersection() {
    circle(r = R_mesh);
    translate([-R_mesh, -R_mesh]) square([2*R_mesh, R_mesh + y_mesh]);
}

// Sloped seat ring: solid between the plate and the closed flap's underside,
// under the flap's footprint but outside the mesh area.
module seat() {
    if (seat_drop > 0) intersection() {
        translate([0, 0, plate_t - 0.01]) linear_extrude(seat_drop + 2) difference() {
            intersection() {
                circle(r = R_flap);
                translate([-R_flap, -R_flap]) square([2*R_flap, R_flap + y_a - knuckle_r - 1]);
            }
            mesh_region2d();
        }
        about_hinge(phi) translate([-60, -150, plate_t - 50]) cube([120, 300, 50]);
    }
}

/* ================= BODY ================= */
module hex_mesh_holes() {
    pitch = mesh_cell + mesh_bar;
    rows  = ceil(R_mesh / (pitch*sin(60))) + 1;
    cols  = ceil(R_mesh / pitch) + 1;
    intersection() {
        union()
            for (r = [-rows:rows], c = [-cols:cols]) {
                x = c*pitch + (abs(r) % 2) * pitch/2;
                y = r*pitch*sin(60);
                translate([x, y]) rotate(30) circle(d = mesh_cell/cos(30), $fn = 6);
            }
        // keep holes inside the seal ring and below the hinge band
        mesh_region2d();
    }
}

module crush_ribs() {
    if (rib_height > 0)
        for (i = [0:rib_count-1]) rotate(i*360/rib_count + 180/rib_count)
            hull() {
                // full-height rib with a 45-degree lead-in at the insertion end
                translate([R_o - 0.5, -0.8, flange_w > 0 ? flange_t : 0])
                    cube([0.5 + rib_height, 1.6, sleeve_len - rib_height - 2 - (flange_w > 0 ? flange_t : 0)]);
                translate([R_o - 0.5, -0.8, 0]) cube([0.5, 1.6, sleeve_len - 0.01]);
            }
}

module body_knuckle(i) {
    translate([kx(i), 0, 0]) difference() {
        hull() {
            translate([0, y_a - knuckle_r, plate_t - 0.01]) cube([kw, 2*knuckle_r, h_a]);
            translate([0, y_a, z_a]) rotate([0, 90, 0]) cylinder(r = knuckle_r, h = kw);
        }
        translate([-1, y_a, z_a]) rotate([0, 90, 0]) cylinder(d = pin_d_body, h = kw + 2, $fn = 24);
    }
}

module body() {
    difference() {
        union() {
            // sleeve
            difference() {
                cylinder(r = R_o, h = sleeve_len);
                translate([0, 0, -1]) cylinder(r = R_i, h = sleeve_len + 2);
            }
            // plate
            cylinder(r = R_i + 0.01, h = plate_t);
            // optional stop flange at the room end
            if (flange_w > 0) cylinder(r = R_o + flange_w, h = flange_t);
            crush_ribs();
            seat();
            for (i = body_k) body_knuckle(i);
        }
        // mesh
        translate([0, 0, -1]) linear_extrude(plate_t + 2) hex_mesh_holes();
        // side slots: let the flap's wide edges swing past the sleeve wall
        // (otherwise it jams at ~38 deg); the duct wall is outside them
        for (s = [-1, 1])
            translate([s > 0 ? 20 : -R_o - 5, slot_y0, plate_t + slot_z0])
                cube([R_o - 15, slot_y1 - slot_y0, sleeve_len]);
        // pin access hole through one side of the sleeve, on the hinge axis
        translate([-R_o - 2, y_a, z_a]) rotate([0, 90, 0])
            cylinder(d = pin_d_flap, h = R_o + 2 - hinge_half + 1, $fn = 24);
        // small chamfer on the insertion end of the sleeve
        translate([0, 0, sleeve_len - 1])
            difference() {
                cylinder(r = R_o + 2, h = 2);
                cylinder(r1 = R_o, r2 = R_o - 1.5, h = 1.5);
            }
    }
}

/* ================= FLAP =================
   Modelled in body coordinates (resting on the plate), then
   lowered to z=0 for export. */
module flap_in_place() {
    difference() {
        union() {
            // disc, cut flat at the hinge axis line
            intersection() {
                translate([0, 0, plate_t]) cylinder(r = R_flap, h = flap_t);
                translate([-R_flap, -R_flap, 0]) cube([2*R_flap, R_flap + y_a, 50]);
            }
            for (i = flap_k) translate([kx(i), 0, 0]) {
                // barrel (rotates within its own radius, so it never hits the plate)
                translate([0, y_a, z_a]) rotate([0, 90, 0]) cylinder(r = knuckle_r, h = kw);
                // web joining barrel to disc
                translate([0, y_a - knuckle_r - 2, plate_t]) cube([kw, knuckle_r + 2, h_a]);
                // stop tab: swings into the sleeve wall at stop_angle
                translate([0.8, y_a - tab_t/2, z_a]) cube([kw - 1.6, tab_t, tab_h]);
            }
        }
        // notches around the body knuckles
        for (i = body_k)
            translate([kx(i) - knuckle_gap, y_a - knuckle_r - knuckle_gap, 0])
                cube([kw + 2*knuckle_gap, 2*knuckle_r + 10, 50]);
        // pin hole
        translate([-hinge_half - 1, y_a, z_a]) rotate([0, 90, 0])
            cylinder(d = pin_d_flap, h = 2*hinge_half + 2, $fn = 24);
    }
}

module flap() { translate([0, 0, -plate_t]) flap_in_place(); }

/* ================= OUTPUT ================= */
if (part == "body") body();
else if (part == "flap") flap();
else if (part == "assembly") {
    color("SteelBlue") body();
    color("Orange")
        about_hinge(max(open_angle, phi)) flap_in_place();
    // pin
    color("Red") translate([-R_o, y_a, z_a]) rotate([0, 90, 0]) cylinder(d = 1.75, h = R_o + hinge_half, $fn = 16);
}
