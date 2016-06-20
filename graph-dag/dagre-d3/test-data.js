function initialize_data(g)
{g.setNode(0,  { label: "Skin lesion" , description: "This is the node that we are investigating"});
 g.setNode(1,  { label: "Lesion of skin and/or skin-associated mucous membrane" });
 g.setNode(2,  { label: "Skin or mucosa lesion" });
 g.setNode(3,  { label: "Skin AND/OR mucosa finding" });
 g.setNode(4,  { label: "Finding by site" });
 g.setNode(5,  { label: "Clinical finding" });
 g.setNode(6,  { label: "SNOMED CT Concept" });
 g.setNode(7,  { label: "Thing" });
 g.setNode(8,  { label: "Soft tissue lesion" });
 g.setNode(9,  { label: "Disorder of soft tissue" });
 g.setNode(10,  { label: "General finding of soft tissue" });
 g.setNode(11,  { label: "Disorder by body site" });
 g.setNode(12,  { label: "Disease" });
 g.setNode(13,  { label: "Disorder of skin" });
 g.setNode(14,  { label: "Skin finding" });
 g.setNode(15,  { label: "Finding of body region" });
 g.setNode(16,  { label: "Integumentary system finding" });
 g.setNode(17,  { label: "Disorder of skin AND/OR subcutaneous tissue" });
 g.setNode(18,  { label: "Disorder of integument" });
 g.setNode(19,  { label: "Disorder of body system" });
 g.setEdge(18, 16,  {lineInterpolate: 'basis'} );
 g.setEdge(19, 11,  {lineInterpolate: 'basis'} );
 g.setEdge(18, 19,  {lineInterpolate: 'basis'} );
 g.setEdge(17, 18,  {lineInterpolate: 'basis'} );
 g.setEdge(17, 9,  {lineInterpolate: 'basis'} );
 g.setEdge(17, 15,  {lineInterpolate: 'basis'} );
 g.setEdge(13, 17,  {lineInterpolate: 'basis'} );
 g.setEdge(16, 4,  {lineInterpolate: 'basis'} );
 g.setEdge(14, 16,  {lineInterpolate: 'basis'} );
 g.setEdge(14, 10,  {lineInterpolate: 'basis'} );
 g.setEdge(14, 3,  {lineInterpolate: 'basis'} );
 g.setEdge(15, 4,  {lineInterpolate: 'basis'} );
 g.setEdge(14, 15,  {lineInterpolate: 'basis'} );
 g.setEdge(13, 14,  {lineInterpolate: 'basis'} );
 g.setEdge(0, 13,  {lineInterpolate: 'basis'} );
 g.setEdge(12, 5,  {lineInterpolate: 'basis'} );
 g.setEdge(11, 12,  {lineInterpolate: 'basis'} );
 g.setEdge(11, 4,  {lineInterpolate: 'basis'} );
 g.setEdge(9, 11,  {lineInterpolate: 'basis'} );
 g.setEdge(10, 4,  {lineInterpolate: 'basis'} );
 g.setEdge(9, 10,  {lineInterpolate: 'basis'} );
 g.setEdge(8, 9,  {lineInterpolate: 'basis'} );
 g.setEdge(0, 8,  {lineInterpolate: 'basis'} );
 g.setEdge(6, 7,  {lineInterpolate: 'basis'} );
 g.setEdge(5, 6,  {lineInterpolate: 'basis'} );
 g.setEdge(4, 5,  {lineInterpolate: 'basis'} );
 g.setEdge(3, 4,  {lineInterpolate: 'basis'} );
 g.setEdge(2, 3,  {lineInterpolate: 'basis'} );
 g.setEdge(1, 2,  {lineInterpolate: 'basis'} );
 g.setEdge(0, 1,  {lineInterpolate: 'basis'} );
}