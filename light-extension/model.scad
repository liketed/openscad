// Parameters
height = 25;
base_outer_d = 120;
top_outer_d = 78;
wall_thickness = 4;

// Calculated parameters for the inner cone
base_inner_d = base_outer_d - wall_thickness;
top_inner_d = top_outer_d - wall_thickness;

// Render hollow cone
difference() {
    // Outer cone
    cylinder(h=height, d1=base_outer_d, d2=top_outer_d, center=false, $fn=360);
    translate([0, 0, 0]) 
    cylinder(h=height + 0, d1=base_inner_d, d2=top_inner_d, center=false, $fn=360);
}
//bottom hollow cylinder
difference() {
    translate([0, 0, -20])    cylinder(h=20, d=base_outer_d, center=false, $fn=360);
    translate([0, 0, -21])    cylinder(h=21, d=base_outer_d-wall_thickness, center=false, $fn=360);
}

// top hollow cylinder
difference() {
    translate([0, 0, height])    cylinder(h=15, d=top_outer_d, center=false, $fn=360);
    translate([0, 0, height])    cylinder(h=15, d=top_outer_d-wall_thickness, center=false, $fn=360);
}


translate([0,-38,32]) rotate([90,0,0]) cylinder(h=4,d=4,center=false,$fn=36);
translate([0,42,32]) rotate([90,0,0]) cylinder(h=4,d=4,center=false,$fn=36);