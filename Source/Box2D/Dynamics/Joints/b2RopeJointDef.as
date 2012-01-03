/*
* Copyright (c) 2006-2010 Erin Catto http://www.gphysics.com
* Copyright (c) 2012 Yang Bo <pop.atry@gmail.com>. All rights reserved. 
*
* This software is provided 'as-is', without any express or implied
* warranty.  In no event will the authors be held liable for any damages
* arising from the use of this software.
* Permission is granted to anyone to use this software for any purpose,
* including commercial applications, and to alter it and redistribute it
* freely, subject to the following restrictions:
* 1. The origin of this software must not be misrepresented; you must not
* claim that you wrote the original software. If you use this software
* in a product, an acknowledgment in the product documentation would be
* appreciated but is not required.
* 2. Altered source versions must be plainly marked as such, and must not be
* misrepresented as being the original software.
* 3. This notice may not be removed or altered from any source distribution.
*/

package Box2D.Dynamics.Joints
{
import Box2D.Common.b2internal;
import Box2D.Common.Math.b2Vec2;
use namespace b2internal;

/**
 * Rope joint definition. This requires two body anchor points and
 * a maximum lengths.
 * Note: by default the connected objects will not collide.
 * see collideConnected in b2JointDef.
 */
public class b2RopeJointDef extends b2JointDef
{
	
	public function b2RopeJointDef()
	{
		type = b2Joint.e_ropeJoint;
		//localAnchorA.Set(-1.0, 0.0);
		//localAnchorB.Set(1.0, 0.0);
		//maxLength = 0.0;
	}
	
	/**
	 * The local anchor point relative to bodyA's origin.
	 */
	public var localAnchorA:b2Vec2 = new b2Vec2();
	
	/**
	 * The local anchor point relative to bodyB's origin.
	 */
	public var localAnchorB:b2Vec2 = new b2Vec2();
	
	/**
	 * The maximum length of the rope.
	 * Warning: this must be larger than b2_linearSlop or
	 * the joint will have no effect.
	 */
	public var maxLength:Number = 0.0;
}
}